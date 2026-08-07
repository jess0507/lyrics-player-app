import 'package:flutter/material.dart';

import 'package:seek_player/features/lyrics/models/lyrics.dart';

/// 非同步歌詞(純文字或無法取得時間戳):整篇可捲動的靜態文字,無高亮。
class LyricsUnsyncedView extends StatelessWidget {
  const LyricsUnsyncedView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, i) {
        final text = lyrics.lines[i].text;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          // 空行保留為段落間距。
          child: Text(
            text.isEmpty ? ' ' : text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        );
      },
    );
  }
}
