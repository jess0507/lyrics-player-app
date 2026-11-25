import 'package:flutter/material.dart';

import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 更新提示 dialog 的共用版面(商店更新與 Shorebird 熱更新共用):
/// 上方 app logo、粗體標題、可選的副標題,下面是全寬的主要按鈕,
/// 最底下是「稍後」。
class UpdatePromptDialog extends StatelessWidget {
  const UpdatePromptDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.onLater,
  });

  final String title;

  /// 標題下方的說明文字,null 時不顯示。
  final String? subtitle;

  final String actionLabel;
  final VoidCallback onAction;

  /// 按下「稍後」時、dialog 關閉前呼叫(例如記錄分析事件)。
  final VoidCallback? onLater;

  static const _logoSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // logo 的橫線在淺色版是黑色、深色版是白色,依主題切換才看得見。
    final isDark = theme.brightness == Brightness.dark;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child:
                    (isDark ? Assets.icon.appLogoDark : Assets.icon.appLogoPng)
                        .image(width: _logoSize, height: _logoSize),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: onAction,
                child: Text(actionLabel),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  onLater?.call();
                  Navigator.of(context).pop();
                },
                child: Text(l10n.update_later),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
