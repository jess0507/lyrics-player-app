import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/cover/models/track_cover_entity.dart';
import 'package:seek_player/features/cover/providers/track_cover_color_provider.dart';
import 'package:seek_player/features/cover/providers/track_cover_provider.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/music_list/models/track_entity.dart';
import 'package:seek_player/features/music_list/models/track_fingerprint_entity.dart';
import 'package:seek_player/features/music_list/providers/music_library_source_provider.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';

/// trackId 改為音檔全檔 SHA-256(plans/38)後的新 flag;與 31 / 33 的 flag 分開,
/// 只跑過那兩版的開發機也會重跑。
const _kDoneKey = 'track_identity_sha256_done';

enum TrackEntityMigrationStatus {
  /// 已完成(或沒有舊資料,不需要遷移)。
  done,

  /// 有舊資料、尚未開始。
  pending,

  /// 遷移中。
  running,

  /// 這次無法遷移(沒有音訊權限、掃到 0 首、或失敗),之後曲庫重新掃描時再試。
  deferred,
}

class TrackEntityMigration extends Notifier<TrackEntityMigrationStatus> {
  Future<void>? _inFlight;

  Isar get _isar => ref.read(isarProvider);

  @override
  TrackEntityMigrationStatus build() {
    final prefs = ref.read(preferencesServiceProvider);
    if (prefs.getBool(_kDoneKey) ?? false) {
      return TrackEntityMigrationStatus.done;
    }
    if (!_hasLegacyData()) {
      unawaited(prefs.setBool(_kDoneKey, true));
      return TrackEntityMigrationStatus.done;
    }
    return TrackEntityMigrationStatus.pending;
  }

  Future<void> runIfNeeded() {
    if (state == TrackEntityMigrationStatus.done) return Future.value();
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    if (!await Permission.audio.isGranted) {
      state = TrackEntityMigrationStatus.deferred;
      return;
    }
    state = TrackEntityMigrationStatus.running;
    try {
      final stats = await _migrate();
      if (stats == null) {
        debugPrint('[TrackEntityMigration] 曲庫掃到 0 首,延後');
        state = TrackEntityMigrationStatus.deferred;
        return;
      }
      await ref.read(preferencesServiceProvider).setBool(_kDoneKey, true);
      state = TrackEntityMigrationStatus.done;
      debugPrint('[TrackEntityMigration] 完成:$stats');
      if (stats.dropped > 0) {
        // 不是錯誤,記一筆評估上線後的影響範圍。
        reportError(
          StateError('TrackEntity 遷移丟棄對不到曲目的資料:$stats'),
          StackTrace.current,
          reason: 'TrackEntityMigration 統計',
        );
      }
    } catch (e, s) {
      // 失敗不寫 flag,之後曲庫重新掃描時再試。
      reportError(e, s, reason: 'TrackEntityMigration 失敗');
      state = TrackEntityMigrationStatus.deferred;
    }
  }

  /// 本機是否有任何可能帶 legacy id 的資料。新安裝全是空的,不必遷移。
  bool _hasLegacyData() =>
      _isar.trackFingerprintEntitys.countSync() > 0 ||
      _isar.trackCoverEntitys.countSync() > 0 ||
      _isar.lyricsEntitys.countSync() > 0 ||
      _isar.dailyTrackStatEntitys.countSync() > 0 ||
      _isar.playlistEntitys
              .filter()
              .trackIdsIsNotEmpty()
              .or()
              .recentlyPlayedIsNotEmpty()
              .countSync() >
          0 ||
      ref.read(lyricsPendingSyncStoreProvider).isNotEmpty;

  Future<_MigrationStats?> _migrate() async {
    // 1. 掃描曲庫:掃到的檔案算好 trackId(音檔全檔 SHA-256)並 upsert 成
    //    TrackEntity。第一次要讀全部檔案,期間由 TrackEntityMigrationGate
    //    顯示「更新音樂庫」進度。
    final scanned = await ref.read(musicLibrarySourceProvider).scan();

    // 曲庫掃到 0 首回 null(對不到任何 trackId,遷移沒有意義)。
    if (scanned.isEmpty) return null;

    final resolver = await _LegacyIdResolver.build(_isar);
    final stats = _MigrationStats();

    // 全 App 唯一的 async 交易(其餘寫入都是 writeTxnSync,混用時 async
    // 進行中開 sync 會丟 IsarError)。遷移由 TrackEntityMigrationGate 擋在
    // UI 前、曲庫載入前跑完,期間不會播放 / 寫統計,所以可以留 async,
    // 避免大量資料卡住 loading 動畫。
    await _isar.writeTxn(() async {
      await _migrateCovers(resolver, stats);
      await _migrateLyrics(resolver, stats);
      await _migratePlaylists(resolver, stats);
      await _migrateStatistics(resolver, stats);
      await _isar.trackCoverEntitys.clear();
      await _isar.trackFingerprintEntitys.clear();
    });
    await ref
        .read(lyricsPendingSyncStoreProvider.notifier)
        .remapToTrackIds((trackId) => resolver.resolve(trackId).firstOrNull);
    await _deleteOrphanCoverFiles();

    // 讓下一次同步以新格式整份推送,覆蓋雲端舊格式資料。
    final backupState = ref.read(backupStateStoreProvider);
    if (stats.playlists > 0) backupState.markPlaylistModified();
    if (stats.lyrics > 0) backupState.markLyricsModified();
    if (stats.statistics > 0) backupState.markStatsModified();

    // 這些 provider 不走 Isar watch,遷移後作廢重讀。
    ref
      ..invalidate(statisticsControllerProvider)
      ..invalidate(trackLyricsProvider)
      ..invalidate(trackCoverProvider)
      ..invalidate(trackCoverColorProvider);
    return stats;
  }

  /// TrackCoverEntity(以舊 sha1 trackId 關聯)→ TrackEntity.coverImagePath。
  Future<void> _migrateCovers(
    _LegacyIdResolver resolver,
    _MigrationStats stats,
  ) async {
    final tracks = _isar.trackEntitys;
    for (final cover in await _isar.trackCoverEntitys.where().findAll()) {
      final trackId = resolver.resolve(cover.trackId).firstOrNull;
      final entities = trackId == null
          ? const <TrackEntity>[]
          : await tracks.where().trackIdEqualTo(trackId).findAll();
      if (entities.isEmpty || entities.first.coverImagePath != null) {
        // 對不到曲目:圖檔留給 _deleteOrphanCoverFiles 一併清掉。
        stats.dropped++;
        continue;
      }
      // 封面以曲目身份為單位:同 trackId 的多個檔案共用。
      final now = DateTime.now();
      for (final e in entities) {
        e
          ..coverImagePath = cover.imagePath
          ..coverColorValue = cover.colorValue
          ..updatedAt = now;
      }
      await tracks.putAllByPath(entities);
      stats.covers++;
    }
  }

  /// LyricsEntity 的 trackId 由舊 sha1 就地改寫成 SHA-256。一首一筆:同一個
  /// trackId 已有歌詞(先遷移到的那筆)時,後來的丟棄;對不到曲目的刪除。
  Future<void> _migrateLyrics(
    _LegacyIdResolver resolver,
    _MigrationStats stats,
  ) async {
    final col = _isar.lyricsEntitys;
    final taken = <String>{};
    for (final lyrics in await col.where().findAll()) {
      final trackId = resolver.resolve(lyrics.trackId).firstOrNull;
      if (trackId == null || !taken.add(trackId)) {
        await col.delete(lyrics.id);
        stats.dropped++;
        continue;
      }
      lyrics.trackId = trackId;
      await col.put(lyrics);
      stats.lyrics++;
    }
  }

  /// 播放清單的 trackIds 依原順序改寫;最近播放逐筆改寫。對不到的移除,
  /// 改寫後重複的只留第一個。
  Future<void> _migratePlaylists(
    _LegacyIdResolver resolver,
    _MigrationStats stats,
  ) async {
    final col = _isar.playlistEntitys;
    for (final playlist in await col.where().findAll()) {
      if (playlist.trackIds.isEmpty && playlist.recentlyPlayed.isEmpty) {
        continue;
      }

      final trackIds = <String>[];
      for (final legacy in playlist.trackIds) {
        final trackId = resolver.resolve(legacy).firstOrNull;
        if (trackId == null) {
          stats.dropped++;
        } else if (!trackIds.contains(trackId)) {
          trackIds.add(trackId);
        }
      }
      playlist.trackIds = trackIds;

      final recentlyPlayed = <RecentlyPlayedEntry>[];
      final seen = <String>{};
      for (final entry in playlist.recentlyPlayed) {
        final trackId = resolver.resolve(entry.trackId).firstOrNull;
        if (trackId == null) {
          stats.dropped++;
        } else if (seen.add(trackId)) {
          recentlyPlayed.add(
            RecentlyPlayedEntry()
              ..trackId = trackId
              ..playedAt = entry.playedAt,
          );
        }
      }
      playlist.recentlyPlayed = recentlyPlayed;
      await col.put(playlist);
      stats.playlists++;
    }
  }

  /// 每日統計的 trackId 改寫成 SHA-256。同一天兩筆對到同一個 trackId 時合併
  /// 次數與時長(一天一曲一筆,見 DailyTrackStatEntity.day);對不到的保留
  /// 原值(統計只用於加總使用量)。
  ///
  /// 直接用 Isar 非同步讀寫(在呼叫端的 writeTxn 內),不經
  /// StatisticsController.restoreFromRemote:那邊是 writeTxnSync,資料量大時
  /// 會卡住 main isolate,loading 動畫跟著停頓。寫完由 [_migrate] invalidate
  /// statisticsControllerProvider 重讀。月總量(PeriodStatEntity)不分曲目,
  /// 合併後加總不變,不用動。
  Future<void> _migrateStatistics(
    _LegacyIdResolver resolver,
    _MigrationStats stats,
  ) async {
    final col = _isar.dailyTrackStatEntitys;
    final days = await col.where().findAll();
    if (days.isEmpty) return;

    final merged = <(String, String), DailyTrackStatEntity>{};
    for (final d in days) {
      final trackId = resolver.resolve(d.trackId).firstOrNull ?? d.trackId;
      final existing = merged[(d.day, trackId)];
      if (existing != null) {
        existing
          ..playCount += d.playCount
          ..listenMs += d.listenMs;
        continue;
      }
      merged[(d.day, trackId)] = DailyTrackStatEntity()
        ..day = d.day
        ..trackId = trackId
        ..title = d.title
        ..playCount = d.playCount
        ..listenMs = d.listenMs;
    }
    await col.clear();
    await col.putAll(merged.values.toList());
    stats.statistics = days.length;
  }

  /// `covers/` 內沒有任何 TrackEntity 引用的圖檔(對不到曲目的舊封面、
  /// 一對多時沒分到的那份)一併刪除。
  Future<void> _deleteOrphanCoverFiles() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/covers');
      if (!dir.existsSync()) return;
      final referenced =
          (await _isar.trackEntitys
                  .filter()
                  .coverImagePathIsNotNull()
                  .coverImagePathProperty()
                  .findAll())
              .whereType<String>()
              .toSet();
      await for (final file in dir.list()) {
        if (file is File && !referenced.contains(file.path)) {
          await file.delete();
        }
      }
    } on FileSystemException catch (e) {
      // 刪不掉不影響遷移。
      debugPrint('[TrackEntityMigration] 清理封面圖檔失敗:$e');
    }
  }
}

/// 舊 trackId(sha1 內容指紋,即 TrackFingerprintEntity.hash)→ 本機有
/// TrackEntity 的新 trackId(音檔全檔 SHA-256)清單。
///
/// 已經是 SHA-256 的值(本機已有該 trackId 的 TrackEntity)原樣回傳。
class _LegacyIdResolver {
  _LegacyIdResolver(this._byHash, this._known);

  /// 指紋 hash → trackId(同內容多份檔案只會對到一個 trackId)。
  final Map<String, List<String>> _byHash;

  /// 本機所有 TrackEntity 的 trackId。
  final Set<String> _known;

  static Future<_LegacyIdResolver> build(Isar isar) async {
    final tracks = await isar.trackEntitys.where().findAll();
    final byPath = {for (final t in tracks) t.path: t.trackId};

    // 指紋快取的 path 與掃描建立的 TrackEntity 以 path 對上;
    // 檔案已不存在(沒掃到)的不收。
    final byHash = <String, List<String>>{};
    for (final f in await isar.trackFingerprintEntitys.where().findAll()) {
      final trackId = byPath[f.path];
      if (trackId == null) continue;
      final trackIds = byHash.putIfAbsent(f.hash, () => []);
      if (!trackIds.contains(trackId)) trackIds.add(trackId);
    }
    return _LegacyIdResolver(byHash, {for (final t in tracks) t.trackId});
  }

  /// 對不到(含 MediaStore 數字 id 等不在指紋表的值)回空清單。
  List<String> resolve(String? legacyId) {
    if (legacyId == null) return const [];
    if (_known.contains(legacyId)) return [legacyId];
    return _byHash[legacyId] ?? const [];
  }
}

class _MigrationStats {
  int covers = 0;
  int lyrics = 0;
  int playlists = 0;
  int statistics = 0;
  int dropped = 0;

  @override
  String toString() =>
      'covers=$covers, lyrics=$lyrics, playlists=$playlists, '
      'statistics=$statistics, dropped=$dropped';
}

final trackEntityMigrationProvider =
    NotifierProvider<TrackEntityMigration, TrackEntityMigrationStatus>(
      TrackEntityMigration.new,
    );
