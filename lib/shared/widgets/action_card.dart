import 'package:flutter/material.dart';

/// 格狀排列用的方形動作卡片:圓角底,icon 在上、文字在下。
/// 工具頁的工具與產出集合共用。
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.tooltip,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  /// 名稱下方的小字(例如曲數);null 時不顯示。
  final String? caption;

  /// 長按顯示的說明;null 時不包 [Tooltip]。
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme.merge(data: const IconThemeData(size: 36), child: icon),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (caption case final caption?)
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final message = tooltip;
    return message == null ? card : Tooltip(message: message, child: card);
  }
}
