import 'package:flutter/material.dart';

import 'package:seek_player/l10n/app_localizations.dart';

/// 同步歌詞被手動捲離目前播放行時顯示的「同步」按鈕;[visible] 切換時淡入淡出。
class LyricsSyncButton extends StatelessWidget {
  const LyricsSyncButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: visible
          // 白底黑字膠囊造型 + 聲波 icon,固定配色不隨主題變動,
          // 疊在播放頁背景上都清楚可辨。
          ? FilledButton.icon(
              key: const ValueKey('lyrics-sync-button'),
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.graphic_eq, size: 22),
              label: Text(
                AppLocalizations.of(context)!.lyrics_scroll_to_current,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
