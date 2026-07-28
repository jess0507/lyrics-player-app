import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../crash_reporter.dart';
import '../firebase_available_provider.dart';
import 'lyrics_sync.dart';
import 'playlists_sync.dart';
import 'settings_sync.dart';
import 'statistics_sync.dart';
import 'sync_state_store.dart';

class SyncService {
  SyncService(this.ref) {
    _init();
  }

  final Ref ref;

  static const _schemaVersion = 6;

  SyncStateStore get _store => ref.read(syncStateStoreProvider);

  LyricsSync get _lyricsSync => ref.read(lyricsSyncProvider);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      FirebaseFirestore.instance.collection('user').doc(uid);

  void _init() {
    if (!ref.read(firebaseAvailableProvider)) {
      debugPrint('[Sync] Firebase 不可用，停用同步');
      return;
    }
    final sub = ref.read(authServiceProvider).authStateChanges().listen((user) {
      if (user == null) {
        debugPrint('[Sync] auth 事件：未登入，不同步');
        return;
      }
      debugPrint('[Sync] auth 事件：uid=${user.uid}');
      unawaited(_onSignedIn(user.uid));
    });
    ref.onDispose(sub.cancel);

    final lifecycle = AppLifecycleListener(
      onResume: () {
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        if (uid == null) return;
        debugPrint('[Sync] App 回前景，檢查是否上傳');
        unawaited(_maybeUpload(uid));
      },
    );
    ref.onDispose(lifecycle.dispose);
  }

  /// 登入成功當下：先依遠端 / 本機時戳決定是否還原，還原後（或跳過）
  /// 仍接著跑一次上傳判斷，讓本機較新的部分補推上雲端。
  Future<void> _onSignedIn(String uid) async {
    try {
      await _restoreFromCloud(uid);
    } catch (e, s) {
      debugPrint('[Sync] 還原失敗，略過：$e');
      reportError(e, s, reason: '登入後從雲端還原失敗');
    }
    await _maybeUpload(uid);
  }

  Future<void> _restoreFromCloud(String uid) async {
    final snapshot = await _userDoc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      // 雲端沒有文件（首次使用）→ 走上傳判斷。
      debugPrint('[Sync] 雲端無文件，跳過還原');
      return;
    }
    final version = (data['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > _schemaVersion) {
      debugPrint('[Sync] 雲端 schemaVersion $version 較新，跳過還原');
      return;
    }

    // 統計、設定、播放清單一律以各自子集合為權威來源，不看主文件版本
    // （見 _schemaVersion 註解）；三者共用主文件的 updatedAt 代表整組
    // 領域的遠端時戳（每次上傳三者一起送，見 _upload）。
    final remoteMainAt = (data['updatedAt'] as Timestamp?)?.toDate();
    if (_shouldPull(remote: remoteMainAt, local: _store.lastModifiedAt)) {
      await ref.read(statisticsSyncProvider).restore(_userDoc(uid));
      await ref.read(settingsSyncProvider).restore(_userDoc(uid));
      await ref.read(playlistsSyncProvider).restore(_userDoc(uid));
      // 還原後更新本機顯示用的「上次同步時間」；lastModifiedAt 不動
      // （還原不算本機變更）。
      _store.markSynced();
      debugPrint('[Sync] 雲端設定/統計/播放清單較新，已還原（remoteUpdatedAt=$remoteMainAt）');
    } else {
      debugPrint('[Sync] 本機設定/統計/播放清單較新或雲端無 updatedAt，跳過還原');
    }

    // 沒有歌詞子集合，不動本機歌詞，由還原後的上傳判斷補推。
    final remoteLyricsAt = (data['lyricsUpdatedAt'] as Timestamp?)?.toDate();
    if (_shouldPull(remote: remoteLyricsAt, local: _store.lyricsModifiedAt)) {
      await _lyricsSync.restore(_userDoc(uid));
      debugPrint('[Sync] 雲端歌詞較新，已還原（remoteUpdatedAt=$remoteLyricsAt）');
    } else {
      debugPrint('[Sync] 本機歌詞較新或雲端無 lyricsUpdatedAt，跳過還原');
    }
  }

  bool _shouldPull({required DateTime? remote, required DateTime? local}) {
    if (remote == null) return false;
    if (local == null) return true;
    return remote.isAfter(local);
  }

  bool _shouldPush({required DateTime? remote, required DateTime? local}) {
    if (remote == null) return true;
    if (local == null) return false;
    return local.isAfter(remote);
  }

  Future<void> _maybeUpload(String uid) async {
    ref.read(statisticsSyncProvider).ensureMigrated();
    final data = (await _userDoc(uid).get()).data();
    final remoteMainAt = (data?['updatedAt'] as Timestamp?)?.toDate();
    final remoteLyricsAt = (data?['lyricsUpdatedAt'] as Timestamp?)?.toDate();
    final mainChanged = _shouldPush(
      remote: remoteMainAt,
      local: _store.lastModifiedAt,
    );
    final lyricsChanged = _shouldPush(
      remote: remoteLyricsAt,
      local: _store.lyricsModifiedAt,
    );
    if (!mainChanged && !lyricsChanged) {
      debugPrint(
        '[Sync] 雲端已是最新，跳過上傳'
        '（remoteUpdatedAt=$remoteMainAt, remoteLyricsUpdatedAt=$remoteLyricsAt）',
      );
      return;
    }
    debugPrint(
      '[Sync] 開始上傳（mainChanged=$mainChanged, lyricsChanged=$lyricsChanged）',
    );
    await _upload(uid);
  }

  /// 統計重設後呼叫：立即上傳歸零快照（tracks 清空、settings 維持現值），
  /// 不等下次同步班次。未登入 / Firebase 不可用時為 no-op。
  Future<void> uploadAfterReset() async {
    if (!ref.read(firebaseAvailableProvider)) {
      debugPrint('[Sync] Firebase 不可用，重設後不上傳');
      return;
    }
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      debugPrint('[Sync] 未登入，重設後不上傳');
      return;
    }
    await _upload(uid);
  }

  /// 帳戶頁面「立即同步」手動觸發：不看變更判斷，直接跑一次上傳
  /// （歌詞子集合仍依 [_shouldPush] 判斷是否真的要推，見 _upload），
  /// 讓使用者能主動確認資料已送上雲端。
  /// 未登入 / Firebase 不可用時回傳 false（no-op）。
  Future<bool> syncNow() async {
    if (!ref.read(firebaseAvailableProvider)) {
      debugPrint('[Sync] Firebase 不可用，略過手動同步');
      return false;
    }
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      debugPrint('[Sync] 未登入，略過手動同步');
      return false;
    }
    return _upload(uid);
  }

  Future<bool> _upload(String uid) async {
    try {
      final userDoc = _userDoc(uid);
      final cloudData = (await userDoc.get()).data();
      final cloudVersion = cloudData?['schemaVersion'] as num?;
      if (cloudVersion != null && cloudVersion.toInt() > _schemaVersion) {
        debugPrint(
          '[Sync] 雲端 schemaVersion ${cloudVersion.toInt()} 較新（本機 App 尚未升級），跳過上傳',
        );
        return false;
      }
      final pushLyrics = _shouldPush(
        remote: (cloudData?['lyricsUpdatedAt'] as Timestamp?)?.toDate(),
        local: _store.lyricsModifiedAt,
      );

      // merge: true——主文件另存 lyricsUpdatedAt（見下方），這裡整份
      // set 會把它抹除，故不能用預設的覆寫語意。
      await userDoc.set({
        'schemaVersion': _schemaVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // 更新本機顯示用的「上次同步時間」（帳戶頁面），與雲端寫入同一
      // 時刻，不影響推 / 拉判斷（一律直接讀 Firestore，見上）。
      _store.markSynced();
      debugPrint('[Sync] 已上傳主文件');
      // 主文件之後才推設定、播放清單、統計與歌詞子集合：失敗不影響已成功
      // 的主文件寫入，下個班次重試即可（子集合推送整批重寫，冪等）。
      await ref.read(settingsSyncProvider).push(userDoc);
      await ref.read(playlistsSyncProvider).push(userDoc);
      await ref.read(statisticsSyncProvider).push(userDoc);
      if (pushLyrics) {
        await _lyricsSync.push(userDoc);
        await userDoc.update({'lyricsUpdatedAt': FieldValue.serverTimestamp()});
      }
      return true;
    } catch (e, s) {
      // 離線、權限、逾時等：靜默略過，下次啟動自然再試。
      debugPrint('[Sync] 上傳失敗，略過：$e');
      reportError(e, s, reason: '統計 / 設定上傳失敗');
      return false;
    }
  }
}

/// 於 App 根 widget watch 一次以啟動同步（建立後自行監聽登入狀態）。
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
