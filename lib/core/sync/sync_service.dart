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

/// 使用者資料與 Firestore `user/{uid}` 同步的調度：觸發時機、變更判斷、
/// schema 版本與主文件組裝。各領域（設定 / 統計 / 播放清單 / 歌詞）的
/// 編解碼與還原分別在 `*_sync.dart`。
///
/// 登入中為上傳備份（App 啟動、回前景、歌詞變更當下與播放清單變更
/// 節流 5 分鐘觸發、背景執行、有變更才上傳）；
/// 登入當下一律以雲端為準還原，
/// 未登入期間的本機資料視為不保存。全程不阻塞 UI、失敗靜默略過不重試，
/// 下次啟動自然再試。詳細策略見 `plans/statistics-isar-firestore-sync.md`。
class SyncService {
  SyncService(this.ref) {
    _init();
  }

  final Ref ref;

  /// Firestore v3：新增 `monthlyTotals`（月粒度期間總量）——它是未來 `days` 明細
  /// v4：新增 `playlists`（播放清單與其有序 trackIds 關係）。
  /// v5：新增 `lyrics/{trackId}` 子集合（見 LyricsSync）。
  /// v5+ 的文件以子集合為歌詞的權威來源。
  static const _schemaVersion = 5;

  /// 播放清單變更觸發上傳的節流窗長。
  static const _playlistPushThrottle = Duration(minutes: 5);

  /// 節流窗內排定的上傳；null 表示無排定。
  Timer? _playlistPushTimer;

  /// 上次由播放清單變更觸發上傳的時間（記憶體內，App 重啟歸零）。
  DateTime? _lastPlaylistPushAt;

  SyncStateStore get _store => ref.read(syncStateStoreProvider);

  LyricsSync get _lyricsSync => ref.read(lyricsSyncProvider);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      FirebaseFirestore.instance.collection('user').doc(uid);

  void _init() {
    if (!ref.read(firebaseAvailableProvider)) {
      debugPrint('[Sync] Firebase 不可用，停用同步');
      return;
    }
    _lyricsSync.markExistingPending();
    // 首個事件是啟動時的既有登入狀態（App 啟動觸發上傳判斷）；
    // 其後的 null -> user 轉變才是「登入成功當下」（先還原判斷）。
    var isStartupEvent = true;
    final sub = ref.read(authServiceProvider).authStateChanges().listen((user) {
      final isStartup = isStartupEvent;
      isStartupEvent = false;
      if (user == null) {
        // 未登入 / 登出：不同步，本機資料照常累計。
        debugPrint('[Sync] auth 事件：未登入（startup=$isStartup），不同步');
        return;
      }
      debugPrint('[Sync] auth 事件：uid=${user.uid}（startup=$isStartup）');
      if (isStartup) {
        unawaited(_maybeUpload(user.uid));
      } else {
        unawaited(_onSignedIn(user.uid));
      }
    });
    ref.onDispose(sub.cancel);

    // 歌詞變更當下立即推送（不等下次班次）；未登入時留著待推記號，
    // 登入後的班次自然補推。
    final lyricsSub = _store.lyricsModifiedEvents.listen((_) {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid == null) {
        debugPrint('[Sync] 歌詞變更但未登入，留待登入後補推');
        return;
      }
      debugPrint('[Sync] 歌詞變更，立即推送');
      unawaited(_upload(uid));
    });
    ref.onDispose(lyricsSub.cancel);

    // 播放清單變更後節流上傳（見 _onPlaylistModified）。
    final playlistSub = _store.playlistModifiedEvents.listen(
      (_) => _onPlaylistModified(),
    );
    ref.onDispose(playlistSub.cancel);
    ref.onDispose(() => _playlistPushTimer?.cancel());

    // App 回到前景時補一次同步班次（登入中、有變更才上傳）。
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

  /// 播放清單變更當下的節流上傳：窗外首次變更立即上傳；窗內的後續
  /// 變更合併為窗末一次（走 _maybeUpload，期間已被別的班次推掉就跳過）。
  /// 未登入時不排程，留著變更時戳由登入後的班次補推。
  void _onPlaylistModified() {
    if (ref.read(authServiceProvider).currentUser == null) {
      debugPrint('[Sync] 播放清單變更但未登入，留待登入後補推');
      return;
    }
    if (_playlistPushTimer != null) return; // 窗內已排定，合併
    final now = DateTime.now();
    final last = _lastPlaylistPushAt;
    final elapsed = last == null ? _playlistPushThrottle : now.difference(last);
    if (elapsed >= _playlistPushThrottle) {
      _lastPlaylistPushAt = now;
      debugPrint('[Sync] 播放清單變更，立即上傳');
      unawaited(_uploadForCurrentUser());
      return;
    }
    final delay = _playlistPushThrottle - elapsed;
    debugPrint('[Sync] 播放清單變更，節流 ${delay.inSeconds}s 後上傳');
    _playlistPushTimer = Timer(delay, () {
      _playlistPushTimer = null;
      _lastPlaylistPushAt = DateTime.now();
      unawaited(_uploadForCurrentUser());
    });
  }

  /// 以當下登入者跑一次上傳判斷；期間登出則不上傳。
  Future<void> _uploadForCurrentUser() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    await _maybeUpload(uid);
  }

  /// 登入成功當下：一律以雲端為準還原；雲端沒有資料才走上傳（互斥）。
  ///
  /// 未登入期間累計的本機資料視為「不想保存」，登入時直接被雲端覆寫。
  /// 還原後仍跑一次上傳判斷：v4 舊文件沒有歌詞子集合，本機歌詞
  /// 保留為待推狀態，這裡順勢補推（文件一併升 v5）；v5 還原後
  /// 無待推項目，判斷會直接跳過。
  Future<void> _onSignedIn(String uid) async {
    try {
      await _restoreFromCloud(uid);
    } catch (e, s) {
      debugPrint('[Sync] 還原失敗，略過：$e');
      reportError(e, s, reason: '登入後從雲端還原失敗');
    }
    await _maybeUpload(uid);
  }

  /// 以雲端快照整份覆寫本機（不合併）。雲端沒有文件或 schema 不相容時
  /// 不動本機，由呼叫端接續的上傳判斷接手。
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

    ref.read(settingsSyncProvider).restore(data['settings']);
    // v3+ 才有 monthlyTotals 欄位。
    ref
        .read(statisticsSyncProvider)
        .restore(data['days'], version >= 3 ? data['monthlyTotals'] : null);
    // v4+ 才有 playlists 欄位；舊文件缺欄位時不動本機清單。
    await ref.read(playlistsSyncProvider).restore(data['playlists']);
    // v5+ 才以歌詞子集合為權威來源（空集合也整份覆寫本機）；
    // v4 舊文件不動本機歌詞，由還原後的上傳判斷補推。
    if (version >= 5) {
      await _lyricsSync.restore(_userDoc(uid));
    }

    // 還原後視同已同步；lastModifiedAt 不動（還原不算本機變更）。
    _store.markSynced();
    debugPrint('[Sync] 已從雲端還原設定、統計、播放清單與歌詞');
  }

  /// 自上次同步後有變更才上傳（App 啟動 / 回前景 / 登入後無雲端資料時觸發）。
  Future<void> _maybeUpload(String uid) async {
    ref.read(statisticsSyncProvider).ensureMigrated();
    final lastModified = _store.lastModifiedAt;
    final lastSync = _store.lastSyncAt;
    final mainChanged =
        lastModified != null &&
        (lastSync == null || lastModified.isAfter(lastSync));
    if (!mainChanged && !_lyricsSync.pushPending) {
      debugPrint(
        '[Sync] 上次同步後無變更，跳過上傳'
        '（lastModifiedAt=$lastModified, lastSyncAt=$lastSync）',
      );
      return;
    }
    debugPrint(
      '[Sync] 開始上傳（lastModifiedAt=$lastModified, lastSyncAt=$lastSync）',
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

  /// `set()` 整份覆寫（不帶 merge）：雲端永遠是單一裝置的完整快照
  /// （last-write-wins，不合併、不加總）。
  Future<void> _upload(String uid) async {
    try {
      final statsFields = ref.read(statisticsSyncProvider).encodeFields();
      final playlists = ref.read(playlistsSyncProvider).encode();
      await _userDoc(uid).set({
        'schemaVersion': _schemaVersion,
        'settings': ref.read(settingsSyncProvider).encode(),
        ...statsFields,
        'playlists': playlists,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _store.markSynced();
      debugPrint(
        '[Sync] 已上傳統計、設定與播放清單'
        '（${(statsFields['days'] as Map).length} 天統計、'
        '${playlists.length} 份清單）',
      );
      // 主文件之後才推歌詞：失敗時 lastLyricsSyncAt 不動，
      // 下個班次由 pushPending 單獨重試（主文件重寫無妨，冪等）。
      if (_lyricsSync.pushPending) await _lyricsSync.push(_userDoc(uid));
    } catch (e, s) {
      // 離線、權限、逾時等：靜默略過，lastSyncAt 不動，下次啟動自然再試。
      debugPrint('[Sync] 上傳失敗，略過：$e');
      reportError(e, s, reason: '統計 / 設定上傳失敗');
    }
  }
}

/// 於 App 根 widget watch 一次以啟動同步（建立後自行監聽登入狀態）。
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
