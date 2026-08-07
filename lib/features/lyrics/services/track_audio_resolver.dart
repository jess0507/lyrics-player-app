import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:seek_player/features/music_list/services/track_fingerprint_service.dart';

/// 由 trackId 反查本機音訊檔真實路徑(歌詞自動產生 / 對時共用)。
///
/// track id 的組成見 music_library.dart:優先為內容指紋
/// (TrackFingerprintService 的 sha1),指紋算不出來的曲目才 fallback 為
/// MediaStore id。因此解析依序嘗試:
/// 1. 指紋快取反查路徑(常態;一次 Isar 查詢)
/// 2. MediaStore id 比對(fallback id 的曲目)
/// 3. 全庫重算指紋比對(檔案被移動、快取路徑失效時的最後手段)
class TrackAudioResolver {
  TrackAudioResolver(this._ref);

  final Ref _ref;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// 解析 [trackId] 對應的音檔路徑;找不到回 null。
  Future<String?> resolve(String trackId) async {
    final fingerprints = _ref.read(trackFingerprintServiceProvider);

    for (final path in fingerprints.cachedPathsForHash(trackId)) {
      if (File(path).existsSync()) {
        debugPrint('[TrackAudioResolver] 指紋快取命中: $path');
        return path;
      }
    }

    final songs = await _audioQuery.querySongs(uriType: UriType.EXTERNAL);
    debugPrint(
      '[TrackAudioResolver] 指紋快取未命中(trackId=$trackId),'
      'MediaStore 共 ${songs.length} 曲,改試 MediaStore id',
    );
    for (final song in songs) {
      if (song.id.toString() == trackId) {
        final data = song.data;
        final exists = data.isNotEmpty && File(data).existsSync();
        debugPrint('[TrackAudioResolver] MediaStore id 命中: $data($exists)');
        return exists ? data : null;
      }
    }

    // 指紋快取失效(例:檔案被搬移,快取路徑已不存在):重算全庫指紋,
    // 以內容找回同一首歌的新路徑。有快取時只重讀有變動的檔案。
    final rehashed = await fingerprints.fingerprints([
      for (final song in songs) song.data,
    ]);
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
