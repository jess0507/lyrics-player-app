import 'package:flutter/material.dart';

import 'package:seek_player/l10n/app_localizations.dart';

/// 編輯歌詞頁編輯中的底部列:字體大小、分享,純圖示平均分布,上緣一條細分隔線。
/// [fontSizeActive] 為字級面板開啟中,字體大小按鈕以主色標示。
class LyricsEditBottomBar extends StatelessWidget {
  const LyricsEditBottomBar({
    super.key,
    required this.onShare,
    required this.onFontSize,
    required this.fontSizeActive,
  });

  static const double iconSize = 24;

  /// null 時分享按鈕停用(文字框為空)。
  final void Function(BuildContext buttonContext)? onShare;
  final VoidCallback onFontSize;
  final bool fontSizeActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final share = onShare;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                iconSize: iconSize,
                visualDensity: VisualDensity.compact,
                tooltip: l10n.lyrics_font_size,
                color: fontSizeActive ? scheme.primary : null,
                icon: const Icon(Icons.text_fields),
                onPressed: onFontSize,
              ),
              Builder(
                builder: (buttonContext) => IconButton(
                  iconSize: iconSize,
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.player_share,
                  icon: const Icon(Icons.ios_share),
                  onPressed: share == null ? null : () => share(buttonContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
