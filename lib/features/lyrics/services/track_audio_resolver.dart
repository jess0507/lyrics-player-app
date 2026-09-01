import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/providers/music_library_source_provider.dart';
import 'package:seek_player/features/music_list/services/track_fingerprint_service.dart';

/// 由 trackId 反查本機音訊檔真實路徑(歌詞自動產生 / 對時共用)。
///
/// track id 的組成見各 MusicLibrarySource:優先為內容指紋
/// (TrackFingerprintService 的 sha1),指紋算不出來的曲目才 fallback
/// (Android:MediaStore id;iOS:檔案路徑)。因此解析依序嘗試:
/// 1. 指紋快取反查路徑(常態;一次 Isar 查詢)
/// 2. fallback id 比對(交由平台來源)
/// 3. 全庫重算指紋比對(檔案被移動、快取路徑失效時的最後手段)
class TrackAudioResolver {
  TrackAudioResolver(this._ref);

  final Ref _ref;

  /// 解析 [trackId] 對應的音檔路徑;找不到回 null。
  Future<String?> resolve(String trackId) async {
    final fingerprints = _ref.read(trackFingerprintServiceProvider);

    for (final path in fingerprints.cachedPathsForHash(trackId)) {
      if (File(path).existsSync()) {
        debugPrint('[TrackAudioResolver] 指紋快取命中: $path');
        return path;
      }
    }

    final source = _ref.read(musicLibrarySourceProvider);
    final fallbackPath = await source.pathForFallbackId(trackId);
    if (fallbackPath != null) {
      debugPrint('[TrackAudioResolver] fallback id 命中: $fallbackPath');
      return fallbackPath;
    }

    // 指紋快取失效(例:檔案被搬移,快取路徑已不存在):重算全庫指紋,
    // 以內容找回同一首歌的新路徑。有快取時只重讀有變動的檔案。
    final paths = await source.audioFilePaths();
    debugPrint(
      '[TrackAudioResolver] 指紋快取與 fallback 皆未命中(trackId=$trackId),'
      '全庫 ${paths.length} 檔重算指紋比對',
    );
    final rehashed = await fingerprints.fingerprints(paths);
    for (final entry in rehashed.entries) {
      if (entry.value == trackId && File(entry.key).existsSync()) {
        debugPrint('[TrackAudioResolver] 重算指紋命中: ${entry.key}');
        return entry.key;
      }
    }

    debugPrint('[TrackAudioResolver] 找不到 trackId=$trackId 對應音檔');
    return null;
  }
}

final trackAudioResolverProvider = Provider<TrackAudioResolver>(
  TrackAudioResolver.new,
);
