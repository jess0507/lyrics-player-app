import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/player/widgets/lyrics_online_search_sheet.dart';

/// 觸發線上搜尋歌詞(LRCLIB):直接開 [showLyricsOnlineSearchSheet],
/// 查詢進度 / 查無結果 / 錯誤與候選選擇都在面板內呈現。
///
/// LRCLIB 為公開 API,不需登入或用量檢查,與 `aiGenerate`/`autoSync` 不同。
Future<void> runLyricsOnlineSearch(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String title,
}) {
  // artist 從音樂庫依 trackId 查回(播放頁只往下傳了 trackId/title,
  // 沒有完整 Track),與 title 一起組成預填的搜尋關鍵字。
  final tracks = ref.read(musicLibraryProvider).valueOrNull ?? const [];
  final track = tracks.where((t) => t.id == trackId).firstOrNull;
  return showLyricsOnlineSearchSheet(
    context,
    ref,
    trackId: trackId,
    title: title,
    artist: track?.artist,
  );
}
