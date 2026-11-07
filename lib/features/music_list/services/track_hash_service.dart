import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/services/content_sha256.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

/// 曲目的音檔 / 歌詞 SHA-256:算好存在 [TrackEntity],送 AI 產生 / 對時任務時
/// 帶給後端判斷是否為同一個任務(見後端 `_reuse_succeeded_task`)。
class TrackHashService {
  TrackHashService(this._ref);

  final Ref _ref;

  TrackRepository get _repo => _ref.read(trackRepositoryProvider);

  /// [pathKey] 的音檔 SHA-256(即送給後端的 `trackId`)。TrackEntity 已有快取
  /// 且檔案大小沒變就直接沿用,否則讀 [audioPath] 全檔重算並寫回。
  /// 算不出來回 null。
  Future<String?> audioSha256(String pathKey, String audioPath) async {
    final entity = _repo.findByPathKey(pathKey);
    final cached = entity?.audioSha256;
    if (cached != null && _sizeOf(audioPath) == entity!.sizeBytes) {
      return cached;
    }
    final hash = await fileSha256(audioPath);
    if (hash != null) _repo.setContentHash(pathKey, audioSha256: hash);
    return hash;
  }

  /// 算 [lines](實際送對時的歌詞行)的 SHA-256 並記到 [pathKey] 的 TrackEntity。
  String lyricsSha256(String pathKey, List<String> lines) {
    final hash = lyricsLinesSha256(lines);
    _repo.setContentHash(pathKey, lyricsSha256: hash);
    return hash;
  }

  static int? _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return null;
    }
  }
}

final trackHashServiceProvider = Provider<TrackHashService>(
  TrackHashService.new,
);
