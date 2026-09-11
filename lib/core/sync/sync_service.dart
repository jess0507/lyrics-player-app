import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/core/backup/last_backup_at_provider.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/core/sync/lyrics_sync.dart';
import 'package:seek_player/core/sync/playlists_sync.dart';
import 'package:seek_player/core/sync/settings_sync.dart';
import 'package:seek_player/core/sync/statistics_sync.dart';

/// 設定 / 播放清單 / 統計 / 歌詞四個領域與 Firestore `user/{uid}` 之間的
/// 同步調度。
///
/// - 登入(含啟動時已登入)當下:先依 `setting/0` 裡各領域的 *UpdatedAt
///   與本機 [BackupStateStore] 的 *ModifiedAt 逐領域比對,雲端較新就拉下來
///   覆寫本機;接著再跑一次上傳判斷,本機較新的部分補推上雲端。
/// - 回前景:只推本機較新的領域。
/// - 整份快照語意、多裝置 last-write-wins、不合併。
///
/// Google Drive 備份(GoogleDriveBackupService)暫時停用,改回本機制;
/// 兩者共用同一個 [BackupStateStore] 作為本機變更時戳來源。
class SyncService {
  SyncService(this.ref) {
    _init();
  }

  final Ref ref;

  /// 雲端 `user/{uid}` 主文件的 schema 版號;UserRecordService 寫主文件時
  /// 也用同一個值,避免彼此把對方判成「較新」而跳過上傳。
  static const schemaVersion = 8;

  BackupStateStore get _store => ref.read(backupStateStoreProvider);

  LyricsSync get _lyricsSync => ref.read(lyricsSyncProvider);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      FirebaseFirestore.instance.collection('user').doc(uid);

  /// 四個領域各自 *UpdatedAt 時戳的存放處(與 SettingsSync 的設定內容共用
  /// 同一份文件,見 settings_sync.dart)。
  DocumentReference<Map<String, dynamic>> _settingDoc(String uid) =>
      _userDoc(uid).collection('setting').doc('0');

  void _init() {
    if (!ref.read(firebaseAvailableProvider)) {
      debugPrint('[Sync] Firebase 不可用,停用同步');
      return;
    }
    _lyricsSync.markExistingPending();
    final sub = ref.read(authServiceProvider).authStateChanges().listen((user) {
      if (user == null) {
        debugPrint('[Sync] auth 事件:未登入,不同步');
        return;
      }
      debugPrint('[Sync] auth 事件:uid=${user.uid}');
      unawaited(_onSignedIn(user.uid));
    });
    ref.onDispose(sub.cancel);

    final lifecycle = AppLifecycleListener(
      onResume: () {
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        if (uid == null) return;
        debugPrint('[Sync] App 回前景,檢查是否上傳');
        unawaited(_maybeUpload(uid));
      },
    );
    ref.onDispose(lifecycle.dispose);
  }

  /// 登入成功當下:先依遠端 / 本機時戳決定是否還原,還原後(或跳過)
  /// 仍接著跑一次上傳判斷,讓本機較新的部分補推上雲端。
  Future<void> _onSignedIn(String uid) async {
    try {
      await _restoreFromCloud(uid);
    } catch (e, s) {
      reportError(e, s, reason: '登入後從雲端還原失敗');
    }
    await _maybeUpload(uid);
  }

  Future<void> _restoreFromCloud(String uid) async {
    final snapshot = await _userDoc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      // 雲端沒有文件(首次使用)→ 走上傳判斷。
      debugPrint('[Sync] 雲端無文件,跳過還原');
      return;
    }
    final version = (data['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > schemaVersion) {
      debugPrint('[Sync] 雲端 schemaVersion $version 較新,跳過還原');
      return;
    }

    // 四個領域一律以各自子集合為權威來源,且各自獨立依 setting/0 裡對應
    // 的 *UpdatedAt 判斷是否還原,互不牽動(見 _upload)。
    final timestamps = (await _settingDoc(uid).get()).data() ?? const {};
    var restoredAny = false;

    if (_shouldPull(
      remote: _remoteAt(timestamps, 'settingUpdatedAt'),
      local: _store.settingModifiedAt,
    )) {
      await ref.read(settingsSyncProvider).restore(_userDoc(uid));
      restoredAny = true;
      debugPrint('[Sync] 雲端設定較新,已還原');
    } else {
      debugPrint('[Sync] 本機設定較新或雲端無 settingUpdatedAt,跳過還原');
    }

    if (_shouldPull(
      remote: _remoteAt(timestamps, 'playlistUpdatedAt'),
      local: _store.playlistModifiedAt,
    )) {
      await ref.read(playlistsSyncProvider).restore(_userDoc(uid));
      restoredAny = true;
      debugPrint('[Sync] 雲端播放清單較新,已還原');
    } else {
      debugPrint('[Sync] 本機播放清單較新或雲端無 playlistUpdatedAt,跳過還原');
    }

    if (_shouldPull(
      remote: _remoteAt(timestamps, 'statsUpdatedAt'),
      local: _store.statsModifiedAt,
    )) {
      await ref.read(statisticsSyncProvider).restore(_userDoc(uid));
      restoredAny = true;
      debugPrint('[Sync] 雲端統計較新,已還原');
    } else {
      debugPrint('[Sync] 本機統計較新或雲端無 statsUpdatedAt,跳過還原');
    }

    if (_shouldPull(
      remote: _remoteAt(timestamps, 'lyricsUpdatedAt'),
      local: _store.lyricsModifiedAt,
    )) {
      await _lyricsSync.restore(_userDoc(uid));
      restoredAny = true;
      debugPrint('[Sync] 雲端歌詞較新,已還原');
    } else {
      debugPrint('[Sync] 本機歌詞較新或雲端無 lyricsUpdatedAt,跳過還原');
    }

    // 還原後更新本機顯示用的「上次同步時間」;各 *ModifiedAt 不動
    // (還原不算本機變更)。
    if (restoredAny) _markSynced();
  }

  DateTime? _remoteAt(Map<String, dynamic> timestamps, String key) =>
      (timestamps[key] as Timestamp?)?.toDate();

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
    final timestamps = (await _settingDoc(uid).get()).data() ?? const {};
    final settingChanged = _shouldPush(
      remote: _remoteAt(timestamps, 'settingUpdatedAt'),
      local: _store.settingModifiedAt,
    );
    final playlistChanged = _shouldPush(
      remote: _remoteAt(timestamps, 'playlistUpdatedAt'),
      local: _store.playlistModifiedAt,
    );
    final statsChanged = _shouldPush(
      remote: _remoteAt(timestamps, 'statsUpdatedAt'),
      local: _store.statsModifiedAt,
    );
    final lyricsChanged = _shouldPush(
      remote: _remoteAt(timestamps, 'lyricsUpdatedAt'),
      local: _store.lyricsModifiedAt,
    );
    if (!settingChanged &&
        !playlistChanged &&
        !statsChanged &&
        !lyricsChanged) {
      debugPrint('[Sync] 雲端已是最新,跳過上傳');
      return;
    }
    debugPrint(
      '[Sync] 開始上傳(setting=$settingChanged, playlist=$playlistChanged, '
      'stats=$statsChanged, lyrics=$lyricsChanged)',
    );
    await _upload(uid);
  }

  /// 統計重設後呼叫:立即上傳歸零快照,不等下次同步班次。
  /// 未登入 / Firebase 不可用時為 no-op。
  Future<void> uploadAfterReset() async {
    if (!ref.read(firebaseAvailableProvider)) {
      debugPrint('[Sync] Firebase 不可用,重設後不上傳');
      return;
    }
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      debugPrint('[Sync] 未登入,重設後不上傳');
      return;
    }
    await _upload(uid);
  }

  /// 帳戶頁面「立即同步」手動觸發:直接跑一次上傳(四個領域仍各自依
  /// [_shouldPush] 判斷是否真的要推,見 _upload)。
  /// 未登入 / Firebase 不可用時回傳 false(no-op)。
  Future<bool> syncNow() async {
    if (!ref.read(firebaseAvailableProvider)) {
      debugPrint('[Sync] Firebase 不可用,略過手動同步');
      return false;
    }
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      debugPrint('[Sync] 未登入,略過手動同步');
      return false;
    }
    return _upload(uid);
  }

  Future<bool> _upload(String uid) async {
    try {
      final userDoc = _userDoc(uid);
      final settingDoc = _settingDoc(uid);
      final cloudVersion =
          (await userDoc.get()).data()?['schemaVersion'] as num?;
      if (cloudVersion != null && cloudVersion.toInt() > schemaVersion) {
        debugPrint(
          '[Sync] 雲端 schemaVersion ${cloudVersion.toInt()} 較新'
          '(本機 App 尚未升級),跳過上傳',
        );
        return false;
      }

      final timestamps = (await settingDoc.get()).data() ?? const {};
      final pushSetting = _shouldPush(
        remote: _remoteAt(timestamps, 'settingUpdatedAt'),
        local: _store.settingModifiedAt,
      );
      final pushPlaylist = _shouldPush(
        remote: _remoteAt(timestamps, 'playlistUpdatedAt'),
        local: _store.playlistModifiedAt,
      );
      final pushStats = _shouldPush(
        remote: _remoteAt(timestamps, 'statsUpdatedAt'),
        local: _store.statsModifiedAt,
      );
      final pushLyrics = _shouldPush(
        remote: _remoteAt(timestamps, 'lyricsUpdatedAt'),
        local: _store.lyricsModifiedAt,
      );

      await userDoc.set({
        'schemaVersion': schemaVersion,
      }, SetOptions(merge: true));
      // 更新本機顯示用的「上次同步時間」(帳戶頁面),不影響推 / 拉判斷
      // (一律直接讀 Firestore,見上)。
      _markSynced();
      debugPrint('[Sync] 已上傳主文件');

      // 四個領域各自獨立推送:推完各自把對應的 *UpdatedAt 寫回 setting/0
      // (merge),失敗不影響其他領域,下個班次重試即可(子集合推送整批
      // 重寫,冪等)。
      if (pushSetting) {
        await ref.read(settingsSyncProvider).push(userDoc);
        await settingDoc.set({
          'settingUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (pushPlaylist) {
        await ref.read(playlistsSyncProvider).push(userDoc);
        await settingDoc.set({
          'playlistUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (pushStats) {
        await ref.read(statisticsSyncProvider).push(userDoc);
        await settingDoc.set({
          'statsUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (pushLyrics) {
        await _lyricsSync.push(userDoc);
        await settingDoc.set({
          'lyricsUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return true;
    } catch (e, s) {
      // 離線、權限、逾時等:靜默略過,下次啟動自然再試。
      reportError(e, s, reason: 'Firestore 同步上傳失敗');
      return false;
    }
  }

  /// 更新「上次同步時間」並通知帳戶頁刷新。
  void _markSynced() {
    _store.markBackedUp();
    ref.read(lastBackupAtProvider.notifier).refresh();
  }
}

/// 於 App 根 widget watch 一次以啟動同步(建立後自行監聽登入狀態)。
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
