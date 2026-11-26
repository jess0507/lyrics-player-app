import 'package:flutter/material.dart';

/// 一排三張 [ActionCard] 的格狀排列,不自行捲動,
/// 放在外層 ListView 中與其他區塊一起捲動。
class ActionCardGrid extends StatelessWidget {
  const ActionCardGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
