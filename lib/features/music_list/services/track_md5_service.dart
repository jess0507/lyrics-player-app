import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/services/content_md5.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

/// 曲目的音檔 / 歌詞 MD5:算好存在 [TrackEntity],送 AI 產生 / 對時任務時
/// 帶給後端判斷是否為同一個任務(見後端 `_reuse_succeeded_task`)。
class TrackMd5Service {
  TrackMd5Service(this._ref);

  final Ref _ref;

  TrackRepository get _repo => _ref.read(trackRepositoryProvider);

  /// [pathKey] 的音檔 MD5。TrackEntity 已有快取且檔案大小沒變就直接沿用,
  /// 否則讀 [audioPath] 全檔重算並寫回。算不出來回 null。
  Future<String?> audioMd5(String pathKey, String audioPath) async {
    final entity = _repo.findByPathKey(pathKey);
    final cached = entity?.audioMd5;
    if (cached != null && _sizeOf(audioPath) == entity!.sizeBytes) {
      return cached;
    }
    final md5 = await fileMd5(audioPath);
    if (md5 != null) _repo.setMd5(pathKey, audioMd5: md5);
    return md5;
  }

  /// 算 [lines](實際送對時的歌詞行)的 MD5 並記到 [pathKey] 的 TrackEntity。
  String lyricsMd5(String pathKey, List<String> lines) {
    final md5 = lyricsLinesMd5(lines);
    _repo.setMd5(pathKey, lyricsMd5: md5);
    return md5;
  }

  static int? _sizeOf(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return null;
    }
  }
}

final trackMd5ServiceProvider = Provider<TrackMd5Service>(
  TrackMd5Service.new,
);
