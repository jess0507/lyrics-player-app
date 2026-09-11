import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/models/lyrics.dart';
import 'package:seek_player/features/lyrics/services/lyrics_parser.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 依 trackId 查本機 Isar 歌詞並解析為內部模型;查無回 null。顯示計畫
/// (`lyrics-display.md`)以目前曲目 id 消費本 provider;匯入 / 刪除 / 背景任務
/// 寫回後由呼叫端 `invalidate` 對應 family 觸發重讀。
///
/// 只讀本機,不降級讀 Firestore `user/{uid}/lyrics/{trackId}`:該文件是
/// 對時 / 產生任務的後端產物,僅由 LyricsPendingSyncService 監聽終態後
/// 寫回 Isar。若這裡也讀雲端,使用者刪掉本機歌詞後會被雲端快照補回。
final trackLyricsProvider = FutureProvider.family<Lyrics?, String>((
  ref,
  trackId,
) async {
  final entity = ref.watch(lyricsRepositoryProvider).findByTrackId(trackId);
  if (entity == null) return null;
  return parseLyrics(entity.content, entity.format);
});
