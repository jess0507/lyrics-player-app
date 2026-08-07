import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/providers/lyrics_font_scale_controller.dart';
import 'package:seek_player/features/player/widgets/adjustment_bottom_sheet.dart';

/// 以底部面板的滑桿調整歌詞字級;面板半遮畫面,上方歌詞可即時預覽,
/// 重置回預設字級。與播放速度面板共用 [AdjustmentBottomSheet] 外觀。
void showLyricsFontSizeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Consumer(
        builder: (context, ref, _) {
          final scale = ref.watch(lyricsFontScaleProvider);
          final controller = ref.read(lyricsFontScaleProvider.notifier);
          return AdjustmentBottomSheet(
            title: l10n.lyrics_font_size,
            onReset: () =>
                controller.setScale(LyricsFontScaleController.defaultScale),
            child: Row(
              children: [
                const Icon(Icons.text_fields, size: 16),
                Expanded(
                  child: Slider(
                    value: scale,
                    min: LyricsFontScaleController.minScale,
                    max: LyricsFontScaleController.maxScale,
                    divisions: 10,
                    label: '${(scale * 100).round()}%',
                    onChanged: controller.setScale,
                  ),
                ),
                const Icon(Icons.text_fields, size: 28),
              ],
            ),
          );
        },
      );
    },
  );
}
