import 'package:flutter/material.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/shared/widgets/themed_illustration.dart';

/// 清單無內容時的空狀態:插圖在上、說明文字在下,置中顯示。
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key, required this.message, this.action});

  final String message;

  /// 說明文字下方的操作按鈕(例如「重新掃描」),沒有就不顯示。
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemedIllustration(
              image: Assets.images.emptyState,
              width: 200,
              height: 160,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
