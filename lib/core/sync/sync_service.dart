import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/core/backup/last_backup_at_provider.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/core/sync/lyrics_sync.dart';
import 'package:seek_player/core/sync/playlists_sync.dart';
import 'package:seek_player/core/sync/settings_sync.dart';
import 'package:seek_player/core/sync/sign_in_sync_plan.dart';
import 'package:seek_player/core/sync/statistics_sync.dart';
import 'package:seek_player/core/sync/sync_domain.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';

/// 設定 / 播放清單 / 統計 / 歌詞四個領域與 Firestore `user/{uid}` 之間的
/// 同步調度。
///
/// - 登入一個這台裝置尚未綁定的帳號([BackupStateStore.boundUid] 不同):
///   由登入頁在登入 loading 期間呼叫 [prepareSignInSync],逐領域看本機 /
///   雲端有沒有資料——本機空就拉、雲端空就推、兩邊都有就把雲端併進本機
///   (以雲端為主,見各領域的 merge)。合併當下不推,改把該領域標為本機
///   已變更,之後重開 / 回前景的 [_maybeUpload] 自然推上去;新帳號雲端
///   全空 → 四個領域整份推上去。接著呼叫 [applySignInSync] 套用並綁定 uid。
///   [prepareSignInSync] 到 [applySignInSync] 之間 [_upload] 一律跳過,
///   避免判斷途中被回前景的上傳蓋掉。
///   App 啟動時已登入但尚未綁定(例如上次登入流程途中被滑掉)走同一套
///   流程([syncAfterSignIn])。
/// - 已綁定的帳號(每次開 App、回前景、登出後再登入同一帳號):只推不拉,
///   依 `setting/0` 裡各領域的 *UpdatedAt 與本機 *ModifiedAt 比對,只推
///   本機較新的領域。雲端只在登入尚未綁定的帳號時才會拉下來 / 合併。
/// - 推送為整份快照語意:已綁定後多裝置之間仍是 last-write-wins。
/// - 每次上傳順便把 App 版本(appVersion / buildNumber / recordedAt)寫進
///   主文件,供後台觀察各使用者的版本分佈;無人讀取,純記錄用途。
///
/// Google Drive 備份(GoogleDriveBackupService)暫時停用,改回本機制;
/// 兩者共用同一個 [BackupStateStore] 作為本機變更時戳來源。

class SyncService {
  SyncService(this.ref) {
    _init();
  }

  final Ref ref;

  /// 雲端 `user/{uid}` 主文件的 schema 版號。
  /// 9:pathKey 由內容指紋(sha1)改為路徑 pathKey(見 TrackPathKey)。
  static const schemaVersion = 9;

  /// 等曲庫掃描完成的上限;冷啟動掃描大音樂庫可能要一段時間。
  static const _libraryTimeout = Duration(seconds: 30);

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
    var firstEvent = true;
    final sub = ref.read(authServiceProvider).authStateChanges().listen((user) {
      final isFirstEvent = firstEvent;
      firstEvent = false;
      if (user == null) {
        debugPrint('[Sync] auth 事件:未登入,不同步');
        return;
      }
      debugPrint('[Sync] auth 事件:uid=${user.uid}');
      // 舊版升級:本 process 第一個事件(持久化 session)且曾同步過,
      // 視為已綁定這個帳號,不跳登入對話框。
      if (isFirstEvent &&
          _store.boundUid == null &&
          _store.lastBackupAt != null) {
        debugPrint('[Sync] 舊版已同步過,直接綁定 uid');
        _store.setBoundUid(user.uid);
      }
      if (_store.boundUid == user.uid) {
        // 已綁定的帳號(開 App、登出後再登入同一帳號):只推不拉。
        debugPrint('[Sync] 已綁定帳號,檢查是否上傳');
        unawaited(_maybeUpload(user.uid));
      } else if (isFirstEvent) {
        unawaited(syncAfterSignIn());
      }
      // 其餘(剛登入未綁定的帳號):由登入頁呼叫 prepareSignInSync /
      // applySignInSync,才能在帳戶頁顯示衝突對話框。
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

  /// 一次跑完登入同步([prepareSignInSync] + [applySignInSync])。用於 App
  /// 啟動時已登入但尚未綁定、手機 OTP 自動驗證等不經登入頁的情境。
  Future<bool> syncAfterSignIn() async {
    final plan = await prepareSignInSync();
    if (plan == null) return false;
    return applySignInSync(plan);
  }

  /// 登入成功後(登入 loading 期間)判斷各領域的推 / 拉 / 合併。
  /// 未登入、已綁定、Firebase 不可用、雲端 schema 較新、流程已在跑或
  /// 讀取失敗時回傳 null(登入本身仍算成功,不影響登入結果)。
  /// 回傳非 null 時呼叫端必須接著呼叫 [applySignInSync]。
  Future<SignInSyncPlan?> prepareSignInSync() async {
    if (!ref.read(firebaseAvailableProvider)) return null;
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null || _store.boundUid == uid) return null;
    if (_signInFlowUid == uid) return null; // 同一帳號的流程已在跑。
    _signInFlowUid = uid;
    if (!await _libraryReady()) {
      _signInFlowUid = null;
      return null;
    }
    try {
      final userDoc = _userDoc(uid);
      final version = ((await userDoc.get()).data()?['schemaVersion'] as num?)
          ?.toInt();
      if (version != null && version > schemaVersion) {
        debugPrint('[Sync] 雲端 schemaVersion $version 較新,跳過登入同步');
        _signInFlowUid = null;
        return null;
      }

      final local = {
        SyncDomain.settings: ref.read(settingsSyncProvider).hasLocalData(),
        SyncDomain.playlists: ref.read(playlistsSyncProvider).hasLocalData(),
        SyncDomain.statistics: () {
          ref.read(statisticsSyncProvider).ensureMigrated();
          return ref.read(statisticsSyncProvider).hasLocalData();
        }(),
        SyncDomain.lyrics: _lyricsSync.hasLocalData(),
      };
      final remote = {
        SyncDomain.settings: await ref
            .read(settingsSyncProvider)
            .hasRemoteData(userDoc),
        SyncDomain.playlists: await ref
            .read(playlistsSyncProvider)
            .hasRemoteData(userDoc),
        SyncDomain.statistics: await ref
            .read(statisticsSyncProvider)
            .hasRemoteData(userDoc),
        SyncDomain.lyrics: await _lyricsSync.hasRemoteData(userDoc),
      };

      final pull = <SyncDomain>{};
      final push = <SyncDomain>{};
      final merge = <SyncDomain>{};
      if (!remote.values.any((v) => v)) {
        // 新帳號(雲端全空):四個領域整份推上去,建立快照與時戳。
        debugPrint('[Sync] 雲端無資料(新帳號),全部上傳');
        push.addAll(SyncDomain.values);
      } else {
        for (final d in SyncDomain.values) {
          switch ((local[d]!, remote[d]!)) {
            case (true, false):
              push.add(d);
            case (false, true):
              pull.add(d);
            case (true, true):
              merge.add(d);
            case (false, false):
              break;
          }
        }
      }
      debugPrint('[Sync] 登入同步判斷:pull=$pull, push=$push, merge=$merge');
      return SignInSyncPlan(uid: uid, pull: pull, push: push, merge: merge);
    } catch (e, s) {
      reportError(e, s, reason: '登入同步判斷失敗');
      _signInFlowUid = null;
      return null;
    }
  }

  /// 套用 [prepareSignInSync] 的結果並綁定 uid:先拉、再把合併領域的雲端
  /// 資料併進本機,最後推「只有本機有」的領域(合併領域不在此推,見
  /// [_mergeDomain])。
  /// 回傳是否成功。
  Future<bool> applySignInSync(SignInSyncPlan plan) async {
    final uid = plan.uid;
    try {
      // 判斷到套用之間可能已登出或換帳號。
      if (ref.read(authServiceProvider).currentUser?.uid != uid) {
        debugPrint('[Sync] 登入同步途中帳號已變更,中止');
        return false;
      }
      debugPrint(
        '[Sync] 登入同步:pull=${plan.pull}, merge=${plan.merge}, '
        'push=${plan.push}',
      );
      final userDoc = _userDoc(uid);
      for (final d in plan.pull) {
        await _restoreDomain(d, userDoc);
      }
      for (final d in plan.merge) {
        await _mergeDomain(d, userDoc);
      }
      if (plan.pull.isNotEmpty || plan.merge.isNotEmpty) _markSynced();

      _store.setBoundUid(uid);
      return await _upload(uid, domains: plan.push);
    } catch (e, s) {
      reportError(e, s, reason: '登入同步失敗');
      return false;
    } finally {
      if (_signInFlowUid == uid) _signInFlowUid = null;
    }
  }

  /// 曲庫是否已就緒:有權限、完整掃描完成(含 TrackEntity 遷移)且掃到的
  /// 曲目數 > 0。未就緒時整次同步跳過——本機沒有曲目,播放清單 / 歌詞都
  /// 對不上 track,備份沒有意義,下載也只會全部被丟掉。
  Future<bool> _libraryReady() async {
    try {
      final tracks = await ref
          .read(musicLibraryProvider.future)
          .timeout(_libraryTimeout);
      if (tracks.isNotEmpty) return true;
      debugPrint('[Sync] 曲庫為空(未授權或沒有音樂),跳過同步');
    } catch (e) {
      debugPrint('[Sync] 曲庫尚未就緒($e),跳過同步');
    }
    return false;
  }

  /// 正在跑登入流程([prepareSignInSync] → [applySignInSync])的 uid,
  /// 避免重複觸發。
  String? _signInFlowUid;

  Future<void> _restoreDomain(
    SyncDomain domain,
    DocumentReference<Map<String, dynamic>> userDoc,
  ) => switch (domain) {
    SyncDomain.settings => ref.read(settingsSyncProvider).restore(userDoc),
    SyncDomain.playlists => ref.read(playlistsSyncProvider).restore(userDoc),
    SyncDomain.statistics => ref.read(statisticsSyncProvider).restore(userDoc),
    SyncDomain.lyrics => _lyricsSync.restore(userDoc),
  };

  /// 把 [domain] 的雲端資料併進本機(以雲端為主),不推送。合併結果可能
  /// 含雲端沒有的本機資料,所以標為本機已變更,讓之後的 [_maybeUpload]
  /// 推上去。設定是一組單值、無從合併,直接用雲端(結果與雲端相同,
  /// 不需標記)。
  Future<void> _mergeDomain(
    SyncDomain domain,
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async {
    switch (domain) {
      case SyncDomain.settings:
        await ref.read(settingsSyncProvider).restore(userDoc);
      case SyncDomain.playlists:
        await ref.read(playlistsSyncProvider).merge(userDoc);
        _store.markPlaylistModified();
      case SyncDomain.statistics:
        await ref.read(statisticsSyncProvider).merge(userDoc);
        _store.markStatsModified();
      case SyncDomain.lyrics:
        await _lyricsSync.merge(userDoc);
        _store.markLyricsModified();
    }
  }

  DateTime? _remoteAt(Map<String, dynamic> timestamps, String key) =>
      (timestamps[key] as Timestamp?)?.toDate();

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
  /// [_shouldPush] 判斷是否真的要推,見 _upload)。帳號尚未綁定時改跑
  /// 不詢問的登入同步([syncAfterSignIn])。
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
    if (_store.boundUid != uid) return syncAfterSignIn();
    return _upload(uid);
  }

  /// [domains] 非 null 時(登入流程)只推指定領域,不比時戳;null 時各領域
  /// 依 [_shouldPush] 判斷。帳號尚未綁定(登入流程未完成)時一律跳過。
  Future<bool> _upload(String uid, {Set<SyncDomain>? domains}) async {
    if (_store.boundUid != uid) {
      debugPrint('[Sync] 帳號尚未完成登入同步,跳過上傳');
      return false;
    }
    if (!await _libraryReady()) return false;
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
      bool shouldPush(SyncDomain d, String key, DateTime? local) =>
          domains?.contains(d) ??
          _shouldPush(remote: _remoteAt(timestamps, key), local: local);
      final pushSetting = shouldPush(
        SyncDomain.settings,
        'settingUpdatedAt',
        _store.settingModifiedAt,
      );
      final pushPlaylist = shouldPush(
        SyncDomain.playlists,
        'playlistUpdatedAt',
        _store.playlistModifiedAt,
      );
      final pushStats = shouldPush(
        SyncDomain.statistics,
        'statsUpdatedAt',
        _store.statsModifiedAt,
      );
      final pushLyrics = shouldPush(
        SyncDomain.lyrics,
        'lyricsUpdatedAt',
        _store.lyricsModifiedAt,
      );

      await userDoc.set(await _userDocData(), SetOptions(merge: true));
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

  /// 主文件內容:schema 版號 + 這台裝置的 App 版本與寫入時間(merge)。
  Future<Map<String, dynamic>> _userDocData() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'schemaVersion': schemaVersion,
      'appVersion': info.version,
      'buildNumber': info.buildNumber,
      'recordedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 更新「上次同步時間」並通知帳戶頁刷新。
  void _markSynced() {
    _store.markBackedUp();
    ref.read(lastBackupAtProvider.notifier).refresh();
  }
}

/// 於 App 根 widget watch 一次以啟動同步(建立後自行監聽登入狀態)。
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref));
