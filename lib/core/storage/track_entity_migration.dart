import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:on_audio_query/on_audio_query.dart';
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
import 'package:seek_player/features/music_list/services/track_path_key.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';

/// v2:plans/33 改為「pathKey 為身份、trackId 保留舊值」;v1 只在開發版跑過。
const _kDoneKey = 'track_entity_migration_v2_done';

/// 舊版的內容指紋 id:40 碼 sha1 hex。
final _sha1Pattern = RegExp(r'^[0-9a-f]{40}$');

/// 遷移狀態。[pending] / [running] 期間由 TrackEntityMigrationGate 蓋上
/// loading 畫面,避免使用者看到 / 操作到舊格式的資料。
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

/// 一次性遷移:為升級前的資料補上 **pathKey**(曲目身份),舊識別碼
/// **trackId**(內容指紋 sha1,或指紋失敗時的 MediaStore 數字 id)原樣保留;
/// 並把 TrackCoverEntity 併進 TrackEntity。見 plans/31 與 plans/33。
///
/// 流程:
/// 1. 一進 app([build])先看 flag:已完成 → [TrackEntityMigrationStatus.done];
///    沒有任何舊資料(新安裝)→ 直接寫 flag。
/// 2. 否則由 TrackEntityMigrationGate 呼叫 [runIfNeeded],顯示 loading 直到結束:
///    1. 掃描曲庫,建立 TrackEntity;
///    2. 以 TrackFingerprintEntity 的 path 算出 pathKey,建立
///       trackId → pathKey 對照(MediaStore 數字 id 另查一次 MediaStore);
///    3. 封面 → TrackEntity.coverImagePath / coverColorValue;
///    4. 歌詞、播放清單(含最近播放)、每日統計補上 pathKey,待同步歌詞任務
///       的 key 改為 pathKey;
///    5. 清空兩個 deprecated collection、刪掉沒有任何曲目引用的封面圖檔;
///    6. 標記同步領域已修改(下次同步以新格式整份推送),寫 flag。
///
/// 一個 trackId 對到多個 pathKey(同內容多份檔案)時:歌詞複製到每一個;封面
/// 只給第一個(圖檔只有一份,共用的話移除其中一首的封面會刪掉別首的圖);
/// 播放清單 / 統計 / 待同步任務取第一個。對不到:歌詞 / 封面 / 最近播放 /
/// 待同步任務丟棄,播放清單不放進 pathKeys(trackIds 仍保留);統計保留,
/// pathKey 暫以 trackId 填入(只用於加總使用量)。
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

  /// 需要時執行遷移;同時多處呼叫共用同一次執行。已完成時立即返回。
  ///
  /// 呼叫端:TrackEntityMigrationGate(一進 app)與 MusicLibrary 掃描前
  /// (確保曲庫 / 同步一定在遷移之後;權限是進 app 後才授予時也從這裡補跑)。
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

  /// 曲庫掃到 0 首回 null(對不到任何 pathKey,遷移沒有意義)。
  Future<_MigrationStats?> _migrate() async {
    // 1. 掃描曲庫:掃到的檔案同時 upsert 成 TrackEntity。
    final scanned = await ref.read(musicLibrarySourceProvider).scan();
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
        .remapToPathKeys((trackId) => resolver.resolve(trackId).firstOrNull);
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

  /// TrackCoverEntity(以 trackId 關聯)→ TrackEntity.coverImagePath。
  Future<void> _migrateCovers(
    _LegacyIdResolver resolver,
    _MigrationStats stats,
  ) async {
    final tracks = _isar.trackEntitys;
    for (final cover in await _isar.trackCoverEntitys.where().findAll()) {
      final pathKey = resolver.resolve(cover.trackId).firstOrNull;
      final entity = pathKey == null
          ? null
          : await tracks.getByPathKey(pathKey);
      if (entity == null || entity.coverImagePath != null) {
        // 對不到曲目:圖檔留給 _deleteOrphanCoverFiles 一併清掉。
        stats.dropped++;
        continue;
      }
      entity
        ..coverImagePath = cover.imagePath
        ..coverColorValue = cover.colorValue
        ..updatedAt = DateTime.now();
      await tracks.putByPathKey(entity);
      stats.covers++;
    }
  }

  /// LyricsEntity 補上 pathKey(一對多時每個 pathKey 各一份,trackId 相同)。
  /// 一首一筆:同一個 pathKey 已有歌詞(先遷移到的那筆)時,後來的丟棄。
  Future<void> _migrateLyrics(
    _LegacyIdResolver resolver,
    _MigrationStats stats,
  ) async {
    final col = _isar.lyricsEntitys;
    final all = await col.where().findAll();
    final taken = {
      for (final l in all)
        if (l.pathKey.isNotEmpty) l.pathKey,
    };
    for (final lyrics in all) {
      if (lyrics.pathKey.isNotEmpty) continue; // 已遷移。
      final trackId = lyrics.trackId;
      final pathKeys = [
        for (final k in resolver.resolve(trackId))
          if (!taken.contains(k)) k,
      ];
      await col.delete(lyrics.id);
      if (pathKeys.isEmpty) {
        stats.dropped++;
        continue;
      }
      for (final pathKey in pathKeys) {
        taken.add(pathKey);
        await col.put(
          LyricsEntity()
            ..pathKey = pathKey
            ..trackId = resolver.legacyOrNull(trackId)
            ..title = lyrics.title
            ..format = lyrics.format
            ..source = lyrics.source
            ..content = lyrics.content
            ..jobId = lyrics.jobId
            ..addedAt = lyrics.addedAt,
        );
      }
      stats.lyrics++;
    }
  }

  /// 依凍結的 trackIds 順序填入 pathKeys;最近播放逐筆補 pathKey。
  Future<void> _migratePlaylists(
    _LegacyIdResolver resolver,
    _MigrationStats stats,
  ) async {
    final col = _isar.playlistEntitys;
    for (final playlist in await col.where().findAll()) {
      final needsPathKeys =
          playlist.pathKeys.isEmpty && playlist.trackIds.isNotEmpty;
      final needsRecent = playlist.recentlyPlayed.any((e) => e.pathKey.isEmpty);
      if (!needsPathKeys && !needsRecent) continue;

      if (needsPathKeys) {
        final pathKeys = <String>[];
        for (final trackId in playlist.trackIds) {
          final pathKey = resolver.resolve(trackId).firstOrNull;
          if (pathKey == null) {
            stats.dropped++;
          } else if (!pathKeys.contains(pathKey)) {
            pathKeys.add(pathKey);
          }
        }
        playlist.pathKeys = pathKeys;
      }

      final recentlyPlayed = <RecentlyPlayedEntry>[];
      final seen = <String>{};
      for (final entry in playlist.recentlyPlayed) {
        final pathKey = entry.pathKey.isNotEmpty
            ? entry.pathKey
            : resolver.resolve(entry.trackId).firstOrNull;
        if (pathKey == null) {
          stats.dropped++;
        } else if (seen.add(pathKey)) {
          recentlyPlayed.add(
            RecentlyPlayedEntry()
              ..pathKey = pathKey
              ..trackId = resolver.legacyOrNull(entry.trackId)
              ..playedAt = entry.playedAt,
          );
        }
      }
      playlist.recentlyPlayed = recentlyPlayed;
      await col.put(playlist);
      stats.playlists++;
    }
  }

  /// 每日統計補上 pathKey。同一天兩筆對到同一個 pathKey 時合併次數與時長
  /// (一天一曲一筆,見 DailyTrackStatEntity.day)。
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
    if (!days.any((d) => d.pathKey.isEmpty)) return;

    final merged = <(String, String), DailyTrackStatEntity>{};
    for (final d in days) {
      final trackId = d.trackId;
      // 對不到也保留:pathKey 暫以 trackId 填入,統計只用於加總使用量。
      final pathKey = d.pathKey.isNotEmpty
          ? d.pathKey
          : resolver.resolve(trackId).firstOrNull ?? trackId ?? '';
      final existing = merged[(d.day, pathKey)];
      if (existing != null) {
        existing
          ..playCount += d.playCount
          ..listenMs += d.listenMs;
        continue;
      }
      merged[(d.day, pathKey)] = DailyTrackStatEntity()
        ..day = d.day
        ..pathKey = pathKey
        ..trackId = resolver.legacyOrNull(trackId)
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

/// trackId(舊識別碼)→ 本機有 TrackEntity 的 pathKey 清單。
class _LegacyIdResolver {
  _LegacyIdResolver(this._known, this._byHash, this._byMediaStoreId);

  /// 本機所有 TrackEntity 的 pathKey。
  final Set<String> _known;

  /// 指紋 sha1 → pathKey(同內容多份檔案會有多個)。
  final Map<String, List<String>> _byHash;

  /// MediaStore 數字 id(指紋失敗時的 fallback id)→ pathKey。
  final Map<String, String> _byMediaStoreId;

  static Future<_LegacyIdResolver> build(Isar isar) async {
    final known = (await isar.trackEntitys.where().pathKeyProperty().findAll())
        .toSet();

    // 指紋快取的 path 與掃描建立的 TrackEntity 以 pathKey 對上。
    final byHash = <String, List<String>>{};
    for (final f in await isar.trackFingerprintEntitys.where().findAll()) {
      final pathKey = TrackPathKey.of(f.path);
      if (!known.contains(pathKey)) continue;
      final pathKeys = byHash.putIfAbsent(f.hash, () => []);
      if (!pathKeys.contains(pathKey)) pathKeys.add(pathKey);
    }

    final byMediaStoreId = <String, String>{};
    try {
      final songs = await OnAudioQuery().querySongs(uriType: UriType.EXTERNAL);
      for (final s in songs) {
        if (s.data.isEmpty) continue;
        final pathKey = TrackPathKey.of(s.data);
        if (known.contains(pathKey)) byMediaStoreId['${s.id}'] = pathKey;
      }
    } catch (e) {
      debugPrint('[TrackEntityMigration] 查詢 MediaStore 失敗:$e');
    }
    return _LegacyIdResolver(known, byHash, byMediaStoreId);
  }

  /// 對不到回空清單。開發版 v1 遷移曾把 pathKey 寫進 trackId,這種值原樣回傳。
  List<String> resolve(String? trackId) {
    if (trackId == null || trackId.isEmpty) return const [];
    if (_known.contains(trackId)) return [trackId];
    if (_sha1Pattern.hasMatch(trackId)) return _byHash[trackId] ?? const [];
    if (_byMediaStoreId[trackId] case final pathKey?) return [pathKey];
    return const [];
  }

  /// 要保留在 trackId 的舊值:本身已是 pathKey(開發版 v1 遷移的產物)
  /// 不算舊識別碼,回 null。
  String? legacyOrNull(String? trackId) =>
      trackId == null || _known.contains(trackId) ? null : trackId;
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
