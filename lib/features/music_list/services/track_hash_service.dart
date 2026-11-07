import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/services/content_sha256.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

/// 曲目身份 trackId(音檔全檔 SHA-256)與歌詞 SHA-256 的計算。
///
/// trackId 在掃描 / 登記曲目時就算好存進 TrackEntity;歌詞 SHA-256 在送
/// 對時任務時算,一併帶給後端判斷是否為同一個任務(見後端
/// `_reuse_succeeded_task`)。
class TrackHashService {
  TrackHashService(this._ref);

  final Ref _ref;

  /// 同時送給原生端計算的檔案數(原生端另有自己的執行緒池)。
  static const _concurrency = 4;

  /// 單一檔案的 trackId;讀不到檔案回 null。
  Future<String?> trackIdOf(String path) => fileSha256(path);

  /// 逐一計算 [paths] 的 trackId,回傳 path → trackId(讀不到的不在結果內)。
  /// 每算完一個檔案呼叫一次 [onProgress](已完成數, 總數)。
  Future<Map<String, String>> trackIdsOf(
    List<String> paths, {
    void Function(int done, int total)? onProgress,
  }) async {
    final result = <String, String>{};
    final total = paths.length;
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (next < total) {
        final path = paths[next++];
        final hash = await fileSha256(path);
        if (hash != null) result[path] = hash;
        onProgress?.call(++done, total);
      }
    }

    await Future.wait([
      for (var i = 0; i < _concurrency && i < total; i++) worker(),
    ]);
    return result;
  }

  /// 算 [lines](實際送對時的歌詞行)的 SHA-256 並記到 [trackId] 的 TrackEntity。
  String lyricsSha256(String trackId, List<String> lines) {
    final hash = lyricsLinesSha256(lines);
    _ref.read(trackRepositoryProvider).setLyricsSha256(trackId, hash);
    return hash;
  }
}

final trackHashServiceProvider = Provider<TrackHashService>(
  TrackHashService.new,
);
