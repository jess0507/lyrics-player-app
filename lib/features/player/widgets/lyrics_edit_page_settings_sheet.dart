import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/player/models/lyrics_paper_color.dart';
import 'package:seek_player/features/player/providers/lyrics_edit_paper_color_controller.dart';
import 'package:seek_player/features/player/widgets/lyrics_edit_font_size_control.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 預覽歌詞時的「頁面調整」面板:背景顏色與字體大小,即時套用到上方頁面。
void showLyricsEditPageSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _PageSettingsSheet(),
  );
}

class _PageSettingsSheet extends ConsumerWidget {
  const _PageSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selected = ref.watch(lyricsEditPaperColorProvider);
    final controller = ref.read(lyricsEditPaperColorProvider.notifier);
    final sectionStyle = theme.textTheme.titleSmall;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    l10n.lyrics_edit_page_settings,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.lyrics_edit_background, style: sectionStyle),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final paper in LyricsPaperColor.values)
                    _PaperSwatch(
                      paper: paper,
                      selected: paper == selected,
                      onTap: () => controller.setColor(paper),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.lyrics_font_size, style: sectionStyle),
            const LyricsEditFontSizeControl(),
          ],
        ),
      ),
    );
  }
}

/// 一個背景顏色色票;[LyricsPaperColor.system] 以主題背景色 + 半色圖示表示。
class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final LyricsPaperColor paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = paper.color ?? scheme.surface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 60,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: selected
            ? Icon(Icons.check, color: paper.textColor ?? scheme.onSurface)
            : paper == LyricsPaperColor.system
            ? Icon(Icons.contrast, size: 18, color: scheme.outline)
            : null,
      ),
    );
  }
}
