import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:seek_player/features/music_list/models/scanned_track.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/services/music_library_source.dart';
import 'package:seek_player/features/music_list/providers/library_hash_progress.dart';
import 'package:seek_player/features/music_list/services/track_hash_service.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

/// Android 音樂庫來源:直接掃描裝置 MediaStore(不複製檔案)。
///
/// 曲目以 MediaStore 的 content URI 播放,因此無需把檔案複製到 App 私有目錄。
/// 掃到的檔案 upsert 成 TrackEntity(metadata 直接取 MediaStore;trackId 為
/// 音檔全檔 SHA-256,只有新檔或內容變動時才讀檔重算);
/// 來源檔被刪除 / 移走後重新掃描即不再出現在曲庫,但 entity 保留
/// (SD 卡暫時卸載等情況,刪掉會連帶失去歌詞 / 封面 / 播放清單成員)。
class MediaStoreMusicSource implements MusicLibrarySource {
  MediaStoreMusicSource(this._ref);

  final Ref _ref;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<List<SongModel>> _queryMusicSongs() async {
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    return [
      for (final s in songs)
        if ((s.isMusic ?? true) && s.data.isNotEmpty) s,
    ];
  }

  @override
  Future<List<Track>> scan() async {
    final songs = await _queryMusicSongs();
    // MediaStore 偶有同一檔案的重複列:同 path 只留第一筆。
    final seen = <String>{};
    final unique = [
      for (final s in songs)
        if (seen.add(s.data)) s,
    ];

    final trackIds = await _resolveTrackIds(unique);

    final scanned = <ScannedTrack>[];
    final tracks = <Track>[];
    for (final s in unique) {
      // 讀不到檔案(算不出 trackId)的不列入曲庫。
      final trackId = trackIds[s.data];
      if (trackId == null) continue;
      final artist = (s.artist == null || s.artist == '<unknown>')
          ? null
          : s.artist;
      final album = (s.album == null || s.album == '<unknown>')
          ? null
          : s.album;
      scanned.add(
        ScannedTrack(
          path: s.data,
          trackId: trackId,
          sizeBytes: s.size,
          modifiedMs: _modifiedMs(s),
          title: s.title,
          artist: artist,
          album: album,
          albumId: s.albumId,
          durationMs: s.duration,
        ),
      );
      tracks.add(
        Track(
          trackId: trackId,
          uri: s.uri ?? Uri.file(s.data).toString(),
          filePath: s.data,
          title: s.title,
          artist: artist,
          album: album,
          albumId: s.albumId,
          durationMs: s.duration,
        ),
      );
    }
    await _ref.read(trackRepositoryProvider).upsertAll(scanned);
    return tracks;
  }

  /// MediaStore date_modified 單位為秒。
  static int _modifiedMs(SongModel s) => (s.dateModified ?? 0) * 1000;

  /// 每個檔案的 trackId(path → trackId)。TrackEntity 已有、且檔案大小與
  /// mtime 都沒變就沿用,其餘(新檔、內容變動)讀全檔重算;計算期間更新
  /// [libraryHashProgressProvider],讓 UI 顯示「更新音樂庫」進度。
  Future<Map<String, String>> _resolveTrackIds(List<SongModel> songs) async {
    final existing = _ref
        .read(trackRepositoryProvider)
        .findAllByPath(songs.map((s) => s.data));
    final result = <String, String>{};
    final toHash = <String>[];
    for (final s in songs) {
      final e = existing[s.data];
      if (e != null &&
          e.trackId.isNotEmpty &&
          e.sizeBytes == s.size &&
          e.modifiedMs == _modifiedMs(s)) {
        result[s.data] = e.trackId;
      } else {
        toHash.add(s.data);
      }
    }
    if (toHash.isEmpty) return result;

    final progress = _ref.read(libraryHashProgressProvider.notifier)
      ..update(0, toHash.length);
    try {
      result.addAll(
        await _ref
            .read(trackHashServiceProvider)
            .trackIdsOf(toHash, onProgress: progress.update),
      );
    } finally {
      progress.clear();
    }
    return result;
  }
}
