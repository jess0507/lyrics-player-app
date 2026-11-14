import 'package:flutter/material.dart';

import 'package:seek_player/features/player/widgets/lyrics_edit_font_size_control.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 編輯歌詞頁的浮動字級面板(預覽與編輯共用):標題 + [LyricsEditFontSizeControl]。
class LyricsEditFontSizePanel extends StatelessWidget {
  const LyricsEditFontSizePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.lyrics_font_size,
              style: theme.textTheme.labelLarge,
            ),
            const LyricsEditFontSizeControl(),
          ],
        ),
      ),
    );
  }
}
