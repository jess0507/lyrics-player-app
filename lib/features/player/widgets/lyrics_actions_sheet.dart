import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/player/widgets/lyrics_action_tiles.dart';

/// 歌詞按鈕點擊後的底部表單:依目前歌詞狀態列出 [LyricsActionTiles]
/// (自動產生 / 匯入 / 自動對時 / 字體大小 / 重新匯入 / 刪除)。
///
/// 後續動作以呼叫端的 [context]/[ref] 執行,避免本表單關閉後沿用已失效的 context。
void showLyricsActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String title,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 解除預設最大高度(螢幕 9/16),依內容撐高,項目多時不會 overflow。
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: LyricsActionTiles(
        actionContext: context,
        actionRef: ref,
        trackId: trackId,
        title: title,
        onSelected: () => Navigator.of(sheetContext).pop(),
      ),
    ),
  );
}
