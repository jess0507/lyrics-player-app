import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/player/providers/lyrics_edit_font_size_controller.dart';

/// 編輯歌詞頁字級調整列:滑桿 + `−` 目前字級 `+`。
class LyricsEditFontSizeControl extends ConsumerWidget {
  const LyricsEditFontSizeControl({super.key});

  static const _min = LyricsEditFontSizeController.minSize;
  static const _max = LyricsEditFontSizeController.maxSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(lyricsEditFontSizeProvider);
    final controller = ref.read(lyricsEditFontSizeProvider.notifier);

    void step(double delta) {
      controller.setSize(size + delta);
      logAnalyticsAction(
        LyricsAction.fontSizeChange,
        source: AnalyticsSource.lyricsEditor,
        option: size + delta,
      );
    }

    return Row(
      children: [
        Expanded(
          child: Slider(
            value: size,
            min: _min,
            max: _max,
            divisions: (_max - _min).round(),
            onChanged: controller.setSize,
            // 拖曳中不記,放開時記最終字級。
            onChangeEnd: (v) => logAnalyticsAction(
              LyricsAction.fontSizeChange,
              source: AnalyticsSource.lyricsEditor,
              option: v,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: size > _min ? () => step(-1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${size.round()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: size < _max ? () => step(1) : null,
        ),
      ],
    );
  }
}
