import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/backup/domain_backup.dart';
import 'package:seek_player/core/backup/drive_backup_file.dart';
import 'package:seek_player/core/backup/drive_link_controller.dart';
import 'package:seek_player/core/backup/drive_link_state.dart';
import 'package:seek_player/core/backup/google_drive_client.dart';
import 'package:seek_player/core/backup/google_drive_exception.dart';
import 'package:seek_player/core/backup/last_backup_at_provider.dart';
import 'package:seek_player/core/backup/link_choice.dart';
import 'package:seek_player/core/backup/lyrics_backup.dart';
import 'package:seek_player/core/backup/playlists_backup.dart';
import 'package:seek_player/core/backup/settings_backup.dart';
import 'package:seek_player/core/backup/statistics_backup.dart';
import 'package:seek_player/core/backup/backup_busy_provider.dart';
import 'package:seek_player/core/backup/backup_outcome.dart';
import 'package:seek_player/core/backup/backup_state_store.dart';

/// 四個領域(設定 / 播放清單 / 統計 / 歌詞)與使用者自己的 Google Drive
/// `appDataFolder` 之間的備份調度(plan 26)。
///
/// 每個領域一個 JSON 檔。自動推:回前景時以 Drive 回傳的 `modifiedTime`
/// (伺服器時鐘)與本機 BackupStateStore 的 *ModifiedAt 逐領域比對,只推本機
/// 較新的。拉只發生在連結當下使用者選「使用雲端備份」([afterLink]),
/// 雲端有檔就整份覆寫。整份快照語意、多裝置 last-write-wins、不合併。
class GoogleDriveBackupService {
  GoogleDriveBackupService(this.ref) {
    _init();
  }

  final Ref ref;

  /// Drive 備份格式版號(寫進每個檔的 appProperties)。
  static const schemaVersion = 1;

  BackupStateStore get _store => ref.read(backupStateStoreProvider);

  GoogleDriveClient get _client => ref.read(googleDriveClientProvider);

  DriveLinkController get _link => ref.read(driveLinkStateProvider.notifier);

  List<DomainBackup> get _domains => [
    ref.read(settingsBackupProvider),
    ref.read(playlistsBackupProvider),
    ref.read(statisticsBackupProvider),
    ref.read(lyricsBackupProvider),
  ];

  BackupBusyController get _busy => ref.read(backupBusyProvider.notifier);

  void _init() {
    ref.read(lyricsBackupProvider).markExistingPending();

    // 啟動只負責取回 session 讓狀態轉為 DriveLinked,不自動同步。
    unawaited(_link.restoreSession());

    final lifecycle = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(lifecycle.dispose);
  }

  void _onResume() {
    if (ref.read(driveLinkStateProvider) is! DriveLinked) return;
    debugPrint('[Backup] App 回前景,檢查是否上傳');
    unawaited(_exclusive(_upload));
  }

  /// 同步一次只跑一件事:回前景、使用者手動觸發可能重疊。
  /// 已有任務在跑時新的觸發直接略過、不排隊(避免連跑多輪耗電),
  /// 回傳 null 表示被略過;執行期間 [backupBusyProvider] 為 true。
  Future<T?> _exclusive<T>(Future<T> Function() task) async {
    if (ref.read(backupBusyProvider)) {
      debugPrint('[Backup] 同步進行中,略過本次觸發');
      return null;
    }
    _busy.busy = true;
    try {
      return await task();
    } finally {
      _busy.busy = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 對外 API(更多頁的備份列 / 統計重設)

  /// 連結成功後由 UI 立即呼叫(中間不可有 await,確保先於回前景的自動
  /// 上傳搶到 busy):
  /// - 雲端沒有備份 → 直接把本機四領域推上去。
  /// - 雲端已有備份 → 由 [chooseWhenCloudHasBackup] 問使用者:
  ///   [LinkChoice.useCloud] 整份拉下來覆寫本機;
  ///   [LinkChoice.keepLocal] 不比時戳整份推上去覆寫雲端。
  /// 問答期間持續持有 busy,回前景不會插進來上傳。
  Future<BackupOutcome> afterLink({
    required Future<LinkChoice> Function() chooseWhenCloudHasBackup,
  }) async {
    final outcome = await _exclusive(() async {
      if (ref.read(driveLinkStateProvider) is! DriveLinked) {
        return BackupOutcome.notLinked;
      }
      Map<String, DriveBackupFile> remote;
      try {
        remote = await _listRemote();
      } on GoogleDriveException catch (e, s) {
        return _handleDriveError(e, s, reason: '列出 Drive 備份失敗');
      } catch (e, s) {
        reportError(e, s, reason: '列出 Drive 備份失敗');
        return BackupOutcome.failed;
      }
      if (remote.isEmpty) {
        debugPrint('[Backup] 雲端沒有備份,推本機資料');
        return _upload(remote: remote);
      }
      final choice = await chooseWhenCloudHasBackup();
      debugPrint('[Backup] 雲端已有備份,使用者選擇 $choice');
      return switch (choice) {
        LinkChoice.useCloud => _restore(remote),
        LinkChoice.keepLocal => _upload(remote: remote, force: true),
      };
    });
    return outcome ?? BackupOutcome.busy;
  }

  /// 統計重設後呼叫:立即推統計歸零快照,不等下次同步班次。
  /// 未連結或已有同步在跑時為 no-op(後者下次班次會再推)。
  Future<void> uploadAfterReset() async {
    if (ref.read(driveLinkStateProvider) is! DriveLinked) {
      debugPrint('[Backup] 未連結 Drive,重設後不上傳');
      return;
    }
    await _exclusive(_upload);
  }

  // ---------------------------------------------------------------------------
  // 內部流程

  /// 逐領域還原:雲端有檔就拉、覆寫本機,不比時戳(連結時選「使用雲端備份」)。
  Future<BackupOutcome> _restore(Map<String, DriveBackupFile> remote) async {
    var restoredAny = false;
    var failed = false;
    for (final domain in _domains) {
      final file = remote[domain.fileName];
      if (file == null) {
        debugPrint('[Backup] 雲端無 ${domain.label},跳過還原');
        continue;
      }
      if ((file.schemaVersion ?? 0) > schemaVersion) {
        debugPrint(
          '[Backup] 雲端 ${domain.label} schemaVersion ${file.schemaVersion} '
          '較新(本機 App 尚未升級),跳過還原',
        );
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
        debugPrint('[Backup] 已還原 ${domain.label}');
      } on GoogleDriveException catch (e, s) {
        final outcome = _handleDriveError(
          e,
          s,
          reason: '還原 ${domain.label} 失敗',
        );
        if (outcome == BackupOutcome.needsRelink) return outcome;
        failed = true;
      } catch (e, s) {
        reportError(e, s, reason: '還原 ${domain.label} 失敗');
        failed = true;
      }
    }
    // 還原後更新顯示用的「上次同步時間」;各 *ModifiedAt 不動(還原不算本機變更)。
    if (restoredAny) _markBackedUp();
    return failed ? BackupOutcome.failed : BackupOutcome.done;
  }

  /// 逐領域上傳本機較新(或雲端沒有)的檔;[force] 為 true 時不比時戳全推
  /// (連結時選「保留本機資料」)。[remote] 未提供時先 list 一次。
  Future<BackupOutcome> _upload({
    Map<String, DriveBackupFile>? remote,
    bool force = false,
  }) async {
    try {
      remote ??= await _listRemote();
    } on GoogleDriveException catch (e, s) {
      return _handleDriveError(e, s, reason: '列出 Drive 備份失敗');
    } catch (e, s) {
      reportError(e, s, reason: '列出 Drive 備份失敗');
      return BackupOutcome.failed;
    }

    var uploadedAny = false;
    var failed = false;
    for (final domain in _domains) {
      final file = remote[domain.fileName];
      if ((file?.schemaVersion ?? 0) > schemaVersion) {
        debugPrint(
          '[Backup] 雲端 ${domain.label} schemaVersion ${file!.schemaVersion} '
          '較新(本機 App 尚未升級),跳過上傳',
        );
        continue;
      }
      if (!force &&
          !_shouldPush(
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
        debugPrint('[Backup] 已上傳 ${domain.label}(${bytes.length} bytes)');
      } on GoogleDriveException catch (e, s) {
        final outcome = _handleDriveError(
          e,
          s,
          reason: '上傳 ${domain.label} 失敗',
        );
        if (outcome == BackupOutcome.needsRelink ||
            outcome == BackupOutcome.driveFull) {
          return outcome;
        }
        failed = true;
      } catch (e, s) {
        // 離線、逾時等:靜默略過,下次班次自然再試。
        reportError(e, s, reason: '上傳 ${domain.label} 失敗');
        failed = true;
      }
    }
    if (uploadedAny) _markBackedUp();
    if (!uploadedAny && !failed) debugPrint('[Backup] 雲端已是最新,跳過上傳');
    return failed ? BackupOutcome.failed : BackupOutcome.done;
  }

  /// 更新「上次同步時間」並通知備份頁刷新。
  void _markBackedUp() {
    _store.markBackedUp();
    ref.read(lastBackupAtProvider.notifier).refresh();
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
      debugPrint('[Backup] 同名備份檔重複(${f.name}),刪除較舊的 ${stale.id}');
      try {
        await _client.delete(stale.id);
      } catch (e, s) {
        reportError(e, s, reason: '刪除重複備份檔失敗');
      }
    }
    return byName;
  }

  /// 401 / scope 撤銷 → 標記需重新連結;其他 Drive 錯誤上報後回對應結果。
  BackupOutcome _handleDriveError(
    GoogleDriveException e,
    StackTrace s, {
    required String reason,
  }) {
    if (e.needsRelink) {
      debugPrint('[Backup] $reason:授權失效(${e.kind}),標記需重新連結');
      _link.markNeedsRelink();
      return BackupOutcome.needsRelink;
    }
    reportError(e, s, reason: reason);
    return switch (e.kind) {
      GoogleDriveErrorKind.quotaExceeded => BackupOutcome.driveFull,
      _ => BackupOutcome.failed,
    };
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

/// 於 App 根 widget watch 一次以啟動同步(建立後自行取回 session 並監聽 lifecycle)。
final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>(
  (ref) => GoogleDriveBackupService(ref),
);
