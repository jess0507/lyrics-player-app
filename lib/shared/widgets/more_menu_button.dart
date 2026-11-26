import 'package:flutter/material.dart';

/// [MoreMenuButton] 的一個選項。
class MoreMenuEntry {
  const MoreMenuEntry({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });

  final Widget icon;
  final String label;
  final VoidCallback onSelected;

  /// false 時選項顯示為停用、不可點(例如掃描中的重新掃描)。
  final bool enabled;
}

/// 頂欄右側的更多按鈕,點擊後列出 [entries](例如新增 / 編輯 /
/// 排序 / 搜尋)。沒有任何選項時不顯示。
class MoreMenuButton extends StatelessWidget {
  const MoreMenuButton({super.key, required this.entries});

  final List<MoreMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert),
      onSelected: (index) => entries[index].onSelected(),
      itemBuilder: (context) => [
        for (final (index, entry) in entries.indexed)
          PopupMenuItem(
            value: index,
            enabled: entry.enabled,
            child: ListTile(
              enabled: entry.enabled,
              leading: entry.icon,
              title: Text(entry.label),
            ),
          ),
      ],
    );
  }
}
