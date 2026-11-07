import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/models/scanned_track.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/services/track_hash_service.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

/// 把曲庫掃描以外取得的單一音訊檔(外部開啟、工具頁選檔)登記成
/// TrackEntity,和曲庫曲目一樣可加歌詞 / 封面 / 統計,並隨同步上雲端。
class TrackRegistrar {
  TrackRegistrar(this._ref);

  final Ref _ref;

  /// 以實體路徑 [path] 建立 / 更新 TrackEntity 並回傳對應的 [Track]。
  /// [uri] 為播放用 URI(未給則用 `file://`);[title] 未給則用檔名。
  /// 檔案不存在、讀不到 stat 或算不出 trackId 回 null。
  Future<Track?> register({
    required String path,
    String? uri,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
  }) async {
    final FileStat stat;
    try {
      stat = await File(path).stat();
    } on FileSystemException {
      return null;
    }
    if (stat.type == FileSystemEntityType.notFound) return null;

    final trackId = await _ref.read(trackHashServiceProvider).trackIdOf(path);
    if (trackId == null) return null;
    final resolvedTitle = (title != null && title.isNotEmpty)
        ? title
        : _fileNameWithoutExtension(path);
    await _ref
        .read(trackRepositoryProvider)
        .upsert(
          ScannedTrack(
            path: path,
            trackId: trackId,
            sizeBytes: stat.size,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            title: resolvedTitle,
            artist: artist,
            album: album,
            durationMs: durationMs,
          ),
        );
    return Track(
      trackId: trackId,
      uri: uri ?? Uri.file(path).toString(),
      filePath: path,
      title: resolvedTitle,
      artist: artist,
      album: album,
      durationMs: durationMs,
    );
  }

  static String _fileNameWithoutExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}

final trackRegistrarProvider = Provider<TrackRegistrar>(TrackRegistrar.new);
