import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';
import 'package:seek_player/features/lyrics/online/models/lrclib_result.dart';
import 'package:seek_player/features/lyrics/online/services/lrclib_client.dart';

/// 組合層:查詢 LRCLIB 候選結果 → 使用者選定後轉存 `LyricsEntity`
/// (`source = LyricsSource.online`)並呼叫既有 `lyricsRepositoryProvider.save`,
/// 行為與手動匯入完全一致。
class LyricsOnlineSearchService {
  LyricsOnlineSearchService(this._client, this._ref);

  final LrclibClient _client;
  final Ref _ref;

  /// 查詢候選結果:走 LRCLIB 的 `q` 關鍵字比對(不限欄位),
  /// 過濾掉純演奏曲 / 無歌詞內容的候選。
  Future<List<LrclibResult>> searchByKeyword(String keyword) async {
    final results = await _client.searchByKeyword(keyword);
    return results.where((r) => r.hasLyrics).toList();
  }

  /// 套用使用者選定的候選結果:優先用 synced(LRC 格式),沒有才退回 plain
  /// (純文字);寫入既有 `LyricsEntity`,不另建 entity。
  Future<void> apply({
    required String trackId,
    required String title,
    required LrclibResult result,
  }) async {
    final entity = LyricsEntity()
      ..trackId = trackId
      ..title = title
      ..format = result.hasSyncedLyrics ? LyricsFormat.lrc : LyricsFormat.txt
      ..source = LyricsSource.online
      ..content = result.hasSyncedLyrics
          ? result.syncedLyrics!
          : result.plainLyrics!
      ..addedAt = DateTime.now();
    await _ref.read(lyricsRepositoryProvider).save(entity);
    _ref.invalidate(trackLyricsProvider(trackId));
  }
}
