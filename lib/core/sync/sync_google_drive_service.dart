import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/sync/domain_backup.dart';
import 'package:seek_player/core/sync/drive_backup_file.dart';
import 'package:seek_player/core/sync/drive_link_controller.dart';
import 'package:seek_player/core/sync/drive_link_state.dart';
import 'package:seek_player/core/sync/google_drive_client.dart';
import 'package:seek_player/core/sync/google_drive_exception.dart';
import 'package:seek_player/core/sync/lyrics_backup.dart';
import 'package:seek_player/core/sync/playlists_backup.dart';
import 'package:seek_player/core/sync/settings_backup.dart';
import 'package:seek_player/core/sync/statistics_backup.dart';
import 'package:seek_player/core/sync/sync_outcome.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';

/// 四個領域(設定 / 播放清單 / 統計 / 歌詞)與使用者自己的 Google Drive
/// `appDataFolder` 之間的備份調度(plan 26,取代 Firestore 的 SyncService)。
///
/// 每個領域一個 JSON 檔;推 / 拉方向由 Drive 回傳的 `modifiedTime`
/// (伺服器時鐘)與本機 SyncStateStore 的 *ModifiedAt 逐領域比對決定,
/// 互不牽動;整份快照語意、多裝置 last-write-wins、不合併。
class SyncGoogleDriveService {
  SyncGoogleDriveService(this.ref) {
    _init();
  }

  final Ref ref;

  /// Drive 備份格式版號(寫進每個檔的 appProperties)。與舊 Firestore 的
  /// v7 無關,兩者不互通。
  static const schemaVersion = 1;

  SyncStateStore get _store => ref.read(syncStateStoreProvider);

  GoogleDriveClient get _client => ref.read(googleDriveClientProvider);

  DriveLinkController get _link => ref.read(driveLinkStateProvider.notifier);

  List<DomainBackup> get _domains => [
    ref.read(settingsBackupProvider),
    ref.read(playlistsBackupProvider),
    ref.read(statisticsBackupProvider),
    ref.read(lyricsBackupProvider),
  ];

  /// 同步一次只跑一件事:啟動、回前景、使用者手動觸發可能重疊,
  /// 串成佇列依序執行。
  Future<void> _queue = Future.value();

  void _init() {
    ref.read(lyricsBackupProvider).markExistingPending();

    // 連結狀態轉為可用(使用者剛連結、或啟動時取回 session)→ 先拉後推。
    ref.listen<DriveLinkState>(driveLinkStateProvider, (prev, next) {
      if (next is DriveLinked && prev is! DriveLinked) {
        debugPrint('[Sync] Drive 已連結(${next.email}),開始同步');
        unawaited(_serialized(_restoreThenUpload));
      }
    });
    unawaited(_onStartup());

    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(driveLinkStateProvider) is! DriveLinked) return;
        debugPrint('[Sync] App 回前景,檢查是否上傳');
        unawaited(_serialized(_upload));
      },
    );
    ref.onDispose(lifecycle.dispose);
  }

  Future<void> _onStartup() async {
    // build() 已是 DriveLinked(session 早就在)時 restoreSession 不會再
    // 觸發狀態轉移,要自己補跑一次同步。
    final alreadyLinked = ref.read(driveLinkStateProvider) is DriveLinked;
    final ok = await _link.restoreSession();
    if (ok && alreadyLinked) unawaited(_serialized(_restoreThenUpload));
  }

  Future<T> _serialized<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  // ---------------------------------------------------------------------------
  // 對外 API(備份頁 / 統計重設)

  /// 備份頁「同步到雲端」:直接跑一次上傳(四領域仍各自依時戳判斷是否真的
  /// 要推),讓使用者主動確認資料已送上雲端。
  Future<SyncOutcome> syncToCloud() => _serialized(() async {
    if (ref.read(driveLinkStateProvider) is! DriveLinked) {
      return SyncOutcome.notLinked;
    }
    return _upload();
  });

  /// 備份頁「同步到本地」:不比時戳,雲端有的檔全部拉下來覆寫本機
  /// (換機 / 誤刪後手動救回)。
  Future<SyncOutcome> syncToLocal() => _serialized(() async {
    if (ref.read(driveLinkStateProvider) is! DriveLinked) {
      return SyncOutcome.notLinked;
    }
    try {
      final remote = await _listRemote();
      if (remote.isEmpty) return SyncOutcome.nothingToRestore;
      return _restore(remote, force: true);
    } on GoogleDriveException catch (e, s) {
      return _handleDriveError(e, s, reason: '同步到本地失敗');
    } catch (e, s) {
      reportError(e, s, reason: '同步到本地失敗');
      return SyncOutcome.failed;
    }
  });

  /// 統計重設後呼叫:立即推統計歸零快照,不等下次同步班次。
  /// 未連結時為 no-op。
  Future<void> uploadAfterReset() async {
    if (ref.read(driveLinkStateProvider) is! DriveLinked) {
      debugPrint('[Sync] 未連結 Drive,重設後不上傳');
      return;
    }
    await _serialized(_upload);
  }

  // ---------------------------------------------------------------------------
  // 內部流程

  /// 連結成功 / 啟動取回 session 當下:先依時戳把雲端較新的領域拉下來,
  /// 再把本機較新的領域推上去。
  Future<void> _restoreThenUpload() async {
    Map<String, DriveBackupFile> remote;
    try {
      remote = await _listRemote();
    } on GoogleDriveException catch (e, s) {
      _handleDriveError(e, s, reason: '列出 Drive 備份失敗');
      return;
    } catch (e, s) {
      reportError(e, s, reason: '列出 Drive 備份失敗');
      return;
    }
    final pulled = await _restore(remote, force: false);
    if (pulled == SyncOutcome.needsRelink) return;
    await _upload(remote: remote);
  }

  /// 逐領域還原。[force] 為 false 時只拉雲端較新的;true 時雲端有檔就拉。
  Future<SyncOutcome> _restore(
    Map<String, DriveBackupFile> remote, {
    required bool force,
  }) async {
    var restoredAny = false;
    var failed = false;
    for (final domain in _domains) {
      final file = remote[domain.fileName];
      if (file == null) {
        debugPrint('[Sync] 雲端無 ${domain.label},跳過還原');
        continue;
      }
      if ((file.schemaVersion ?? 0) > schemaVersion) {
        debugPrint(
          '[Sync] 雲端 ${domain.label} schemaVersion ${file.schemaVersion} '
          '較新(本機 App 尚未升級),跳過還原',
        );
        continue;
      }
      if (!force &&
          !_shouldPull(
            remote: file.modifiedTime,
            local: domain.localModifiedAt,
          )) {
        debugPrint('[Sync] 本機 ${domain.label} 較新,跳過還原');
        continue;
      }
      try {
        final bytes = await _client.download(file.id);
        final json = jsonDecode(utf8.decode(bytes));
        if (json is! Map<String, dynamic>) {
          throw FormatException('${domain.fileName} 不是 JSON object');
        }
        await domain.restore(json);
        restoredAny = true;
        debugPrint('[Sync] 已還原 ${domain.label}');
      } on GoogleDriveException catch (e, s) {
        final outcome = _handleDriveError(
          e,
          s,
          reason: '還原 ${domain.label} 失敗',
        );
        if (outcome == SyncOutcome.needsRelink) return outcome;
        failed = true;
      } catch (e, s) {
        reportError(e, s, reason: '還原 ${domain.label} 失敗');
        failed = true;
      }
    }
    // 還原後更新顯示用的「上次同步時間」;各 *ModifiedAt 不動(還原不算本機變更)。
    if (restoredAny) _store.markSynced();
    return failed ? SyncOutcome.failed : SyncOutcome.done;
  }

  /// 逐領域上傳本機較新(或雲端沒有)的檔。[remote] 未提供時先 list 一次。
  Future<SyncOutcome> _upload({Map<String, DriveBackupFile>? remote}) async {
    ref.read(statisticsBackupProvider).ensureMigrated();
    try {
      remote ??= await _listRemote();
    } on GoogleDriveException catch (e, s) {
      return _handleDriveError(e, s, reason: '列出 Drive 備份失敗');
    } catch (e, s) {
      reportError(e, s, reason: '列出 Drive 備份失敗');
      return SyncOutcome.failed;
    }

    var uploadedAny = false;
    var failed = false;
    for (final domain in _domains) {
      final file = remote[domain.fileName];
      if ((file?.schemaVersion ?? 0) > schemaVersion) {
        debugPrint(
          '[Sync] 雲端 ${domain.label} schemaVersion ${file!.schemaVersion} '
          '較新(本機 App 尚未升級),跳過上傳',
        );
        continue;
      }
      if (!_shouldPush(
        remote: file?.modifiedTime,
        local: domain.localModifiedAt,
      )) {
        continue;
      }
      try {
        final bytes = utf8.encode(jsonEncode(domain.encode()));
        await _client.upload(
          name: domain.fileName,
          bytes: Uint8List.fromList(bytes),
          schemaVersion: schemaVersion,
          existing: file,
        );
        uploadedAny = true;
        debugPrint('[Sync] 已上傳 ${domain.label}(${bytes.length} bytes)');
      } on GoogleDriveException catch (e, s) {
        final outcome = _handleDriveError(
          e,
          s,
          reason: '上傳 ${domain.label} 失敗',
        );
        if (outcome == SyncOutcome.needsRelink ||
            outcome == SyncOutcome.driveFull) {
          return outcome;
        }
        failed = true;
      } catch (e, s) {
        // 離線、逾時等:靜默略過,下次班次自然再試。
        reportError(e, s, reason: '上傳 ${domain.label} 失敗');
        failed = true;
      }
    }
    if (uploadedAny) _store.markSynced();
    if (!uploadedAny && !failed) debugPrint('[Sync] 雲端已是最新,跳過上傳');
    return failed ? SyncOutcome.failed : SyncOutcome.done;
  }

  /// 列出 appDataFolder,以檔名為 key。同名多份(上傳中斷後重試才可能
  /// 出現)取 modifiedTime 最新者,其餘順手刪掉。
  Future<Map<String, DriveBackupFile>> _listRemote() async {
    final files = await _client.list();
    final byName = <String, DriveBackupFile>{};
    for (final f in files) {
      final kept = byName[f.name];
      if (kept == null) {
        byName[f.name] = f;
        continue;
      }
      final (newer, stale) = f.modifiedTime.isAfter(kept.modifiedTime)
          ? (f, kept)
          : (kept, f);
      byName[f.name] = newer;
      debugPrint('[Sync] 同名備份檔重複(${f.name}),刪除較舊的 ${stale.id}');
      try {
        await _client.delete(stale.id);
      } catch (e, s) {
        reportError(e, s, reason: '刪除重複備份檔失敗');
      }
    }
    return byName;
  }

  /// 401 / scope 撤銷 → 標記需重新連結;其他 Drive 錯誤上報後回對應結果。
  SyncOutcome _handleDriveError(
    GoogleDriveException e,
    StackTrace s, {
    required String reason,
  }) {
    if (e.needsRelink) {
      debugPrint('[Sync] $reason:授權失效(${e.kind}),標記需重新連結');
      _link.markNeedsRelink();
      return SyncOutcome.needsRelink;
    }
    reportError(e, s, reason: reason);
    return switch (e.kind) {
      GoogleDriveErrorKind.quotaExceeded => SyncOutcome.driveFull,
      _ => SyncOutcome.failed,
    };
  }

  static bool _shouldPull({
    required DateTime? remote,
    required DateTime? local,
  }) {
    if (remote == null) return false;
    if (local == null) return true;
    return remote.isAfter(local);
  }

  static bool _shouldPush({
    required DateTime? remote,
    required DateTime? local,
  }) {
    if (remote == null) return true;
    if (local == null) return false;
    return local.isAfter(remote);
  }
}

/// 於 App 根 widget watch 一次以啟動同步(建立後自行監聽連結狀態與 lifecycle)。
final syncGoogleDriveServiceProvider = Provider<SyncGoogleDriveService>(
  (ref) => SyncGoogleDriveService(ref),
);
