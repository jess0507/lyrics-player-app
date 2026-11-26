import 'package:flutter/material.dart';

/// 「更多」頁的圓角卡片群組:把多個 tile 包在同一張卡片裡,
/// tile 之間以內縮分隔線隔開。所有區塊共用,讓各列外觀一致。
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                const Divider(height: 1, indent: 16, endIndent: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
