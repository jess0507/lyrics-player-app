import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/services/music_library_source.dart';
import 'package:seek_player/features/music_list/services/track_fingerprint_service.dart';

/// Android 音樂庫來源:直接掃描裝置 MediaStore(不複製檔案、不落地資料庫)。
///
/// 曲目以 MediaStore 的 content URI 播放,因此無需把檔案複製到 App 私有目錄;
/// 缺點是來源檔被刪除/移走後,重新掃描即不再出現(屬預期)。
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
        if (s.isMusic ?? true) s,
    ];
  }

  /// track id 以檔案內容指紋為準(跨裝置/重掃穩定);讀不到檔案內容時
  /// 退回 MediaStore id(僅該曲維持裝置綁定)。
  @override
  Future<List<Track>> scan() async {
    final musicSongs = await _queryMusicSongs();
    final fingerprints = await _ref
        .read(trackFingerprintServiceProvider)
        .fingerprints([for (final s in musicSongs) s.data]);

    return [
      for (final s in musicSongs)
        Track(
          id: fingerprints[s.data] ?? s.id.toString(),
          uri: s.uri ?? Uri.file(s.data).toString(),
          filePath: s.data,
          title: s.title,
          artist: (s.artist == null || s.artist == '<unknown>')
              ? null
              : s.artist,
          album: (s.album == null || s.album == '<unknown>') ? null : s.album,
          albumId: s.albumId,
          durationMs: s.duration,
        ),
    ];
  }

  @override
  Future<List<String>> audioFilePaths() async => [
    for (final s in await _queryMusicSongs()) s.data,
  ];

  @override
  Future<String?> pathForFallbackId(String trackId) async {
    for (final song in await _queryMusicSongs()) {
      if (song.id.toString() == trackId) {
        final data = song.data;
        return (data.isNotEmpty && File(data).existsSync()) ? data : null;
      }
    }
    return null;
  }
}
