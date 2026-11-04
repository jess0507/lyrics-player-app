import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:seek_player/features/music_list/models/scanned_track.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/services/music_library_source.dart';
import 'package:seek_player/features/music_list/services/track_path_key.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

/// Android 音樂庫來源:直接掃描裝置 MediaStore(不複製檔案)。
///
/// 曲目以 MediaStore 的 content URI 播放,因此無需把檔案複製到 App 私有目錄。
/// 掃到的檔案 upsert 成 TrackEntity(metadata 直接取 MediaStore,不讀檔);
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
    final scanned = <ScannedTrack>[];
    final tracks = <Track>[];
    final seen = <String>{};
    for (final s in songs) {
      final pathKey = TrackPathKey.of(s.data);
      // MediaStore 偶有同一檔案的重複列:同 pathKey 只留第一筆。
      if (!seen.add(pathKey)) continue;
      final artist = (s.artist == null || s.artist == '<unknown>')
          ? null
          : s.artist;
      final album = (s.album == null || s.album == '<unknown>')
          ? null
          : s.album;
      scanned.add(
        ScannedTrack(
          path: s.data,
          pathKey: pathKey,
          sizeBytes: s.size,
          // MediaStore date_modified 單位為秒。
          modifiedMs: (s.dateModified ?? 0) * 1000,
          title: s.title,
          artist: artist,
          album: album,
          albumId: s.albumId,
          durationMs: s.duration,
        ),
      );
      tracks.add(
        Track(
          pathKey: pathKey,
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
}
