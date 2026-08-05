import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seek_player/features/cover/services/cover_import_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/services/track_fingerprint_service.dart';

/// 本機音樂庫：直接掃描裝置 MediaStore（不複製檔案、不另存資料庫）。
///
/// 曲目以 MediaStore 的 content URI 播放，因此無需把檔案複製到 App 私有目錄；
/// 缺點是來源檔被刪除／移走後，重新掃描即不再出現（屬預期）。
class MusicLibrary extends AsyncNotifier<List<Track>> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  Future<List<Track>> build() async {
    // build 不主動彈權限對話框；已授權才掃描，否則回空清單，
    // 待使用者於列表頁透過 refresh() 觸發授權流程。
    if (await Permission.audio.isGranted) {
      final tracks = await _scan();
      _backfillCoverColors();
      return tracks;
    }
    return const [];
  }

  /// 查詢裝置上所有音樂並映射為 [Track]。
  ///
  /// track id 以檔案內容指紋為準(跨裝置 / 重掃穩定);讀不到檔案內容時
  /// 退回 MediaStore id(僅該曲維持裝置綁定)。
  Future<List<Track>> _scan() async {
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final musicSongs = [
      for (final s in songs)
        if (s.isMusic ?? true) s,
    ];
    final fingerprints = await ref
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

  /// 重新掃描裝置音樂庫（權限應由呼叫端先確保）。
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_scan);
    if (state.hasValue) _backfillCoverColors();
  }

  /// 載入音樂後,背景補算既有封面尚未快取的主色(fire-and-forget,
  /// 不阻塞清單)。避免播放頁切歌時才即時解析封面圖造成卡頓。
  void _backfillCoverColors() {
    unawaited(ref.read(coverImportServiceProvider).backfillMissingColors());
  }
}

final musicLibraryProvider = AsyncNotifierProvider<MusicLibrary, List<Track>>(
  MusicLibrary.new,
);
