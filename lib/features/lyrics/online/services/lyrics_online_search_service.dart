import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lyrics_entity.dart';
import '../../providers/track_lyrics_provider.dart';
import '../../services/lyrics_repository.dart';
import '../models/lrclib_result.dart';
import 'lrclib_client.dart';

/// 一次線上搜尋歌詞的查詢參數,皆已存在於現有 `Track` model。
class LyricsOnlineSearchQuery {
  const LyricsOnlineSearchQuery({
    required this.title,
    this.artist,
    this.album,
    this.durationMs,
  });

  final String title;
  final String? artist;
  final String? album;
  final int? durationMs;
}

/// 組合層:查詢 LRCLIB 候選結果 → 使用者選定後轉存 `LyricsEntity`
/// (`source = LyricsSource.online`)並呼叫既有 `lyricsRepositoryProvider.save`,
/// 行為與手動匯入完全一致。
class LyricsOnlineSearchService {
  LyricsOnlineSearchService(this._client, this._ref);

  final LrclibClient _client;
  final Ref _ref;

  /// 查詢候選結果:有 artist 時先試精確 `get`,命中且有歌詞內容直接回單筆;
  /// 否則退回模糊 `search`,過濾掉純演奏曲 / 無歌詞內容的候選。
  Future<List<LrclibResult>> search(LyricsOnlineSearchQuery query) async {
    final durationSeconds = query.durationMs == null
        ? null
        : query.durationMs! ~/ 1000;
    final artist = query.artist;
    if (artist != null && artist.isNotEmpty) {
      final exact = await _client.get(
        trackName: query.title,
        artistName: artist,
        albumName: query.album,
        durationSeconds: durationSeconds,
      );
      if (exact != null && exact.hasLyrics) return [exact];
    }
    final results = await _client.search(
      trackName: query.title,
      artistName: query.artist,
      albumName: query.album,
    );
    return results.where((r) => r.hasLyrics).toList();
  }

  /// 使用者自行編輯查詢字串後的重查:改走 LRCLIB 的 `q` 關鍵字比對
  /// (不限欄位),同樣過濾掉純演奏曲 / 無歌詞內容的候選。
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
