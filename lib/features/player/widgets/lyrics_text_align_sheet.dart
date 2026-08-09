import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/providers/lyrics_text_align_controller.dart';
import 'package:seek_player/features/player/widgets/adjustment_bottom_sheet.dart';

/// 以底部面板切換歌詞的左 / 中 / 右對齊;面板半遮畫面,上方歌詞可即時預覽,
/// 重置回預設(置左)。與字級 / 播放速度面板共用 [AdjustmentBottomSheet] 外觀。
void showLyricsTextAlignSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Consumer(
        builder: (context, ref, _) {
          final align = ref.watch(lyricsTextAlignProvider);
          final controller = ref.read(lyricsTextAlignProvider.notifier);
          return AdjustmentBottomSheet(
            title: l10n.lyrics_text_align,
            onReset: () =>
                controller.setAlign(LyricsTextAlignController.defaultAlign),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<LyricsTextAlign>(
                  showSelectedIcon: false,
                  segments: [
                    for (final value in LyricsTextAlign.values)
                      ButtonSegment(
                        value: value,
                        icon: Icon(value.icon),
                        label: Text(_label(l10n, value)),
                      ),
                  ],
                  selected: {align},
                  onSelectionChanged: (selection) =>
                      controller.setAlign(selection.first),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

String _label(AppLocalizations l10n, LyricsTextAlign align) => switch (align) {
  LyricsTextAlign.left => l10n.lyrics_text_align_left,
  LyricsTextAlign.center => l10n.lyrics_text_align_center,
  LyricsTextAlign.right => l10n.lyrics_text_align_right,
};
