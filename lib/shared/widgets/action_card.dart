import 'package:flutter/material.dart';

/// 格狀排列用的方形動作卡片:圓角底,漸層上色的 icon 在上、文字在下。
/// 工具頁的工具與產出集合共用。
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.caption,
    this.tooltip,
  });

  final Widget icon;
  final String label;

  /// icon 的主色:以它做漸層,讓每張卡片有自己的辨識色。
  final Color accent;
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
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GradientIcon(accent: accent, icon: icon),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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

/// 漸層上色的 icon:左上偏亮、右下為主色,直接放在卡片上不另加底框。
class _GradientIcon extends StatelessWidget {
  const _GradientIcon({required this.accent, required this.icon});

  final Color accent;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(accent, Colors.white, 0.35)!, accent],
      ).createShader(bounds),
      // 先塗白色,再由 shader 以 srcIn 換成漸層。
      child: IconTheme.merge(
        data: const IconThemeData(size: 44, color: Colors.white),
        child: icon,
      ),
    );
  }
}
