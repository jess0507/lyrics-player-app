import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/services/track_repository.dart';

/// 由 pathKey反查本機音訊檔真實路徑(歌詞自動產生 / 對時、
/// 內嵌封面抽取共用)。
class TrackAudioResolver {
  TrackAudioResolver(this._ref);

  final Ref _ref;

  /// 解析 [pathKey] 對應的音檔路徑;找不到或檔案已不存在回 null。
  Future<String?> resolve(String pathKey) async {
    final entity = _ref.read(trackRepositoryProvider).findByPathKey(pathKey);
    final path = entity?.path;
    if (path != null && File(path).existsSync()) return path;
    debugPrint('[TrackAudioResolver] 找不到 pathKey=$pathKey 對應音檔');
    return null;
  }
}

final trackAudioResolverProvider = Provider<TrackAudioResolver>(
  TrackAudioResolver.new,
);
