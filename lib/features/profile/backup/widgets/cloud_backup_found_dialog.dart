import 'package:flutter/material.dart';

import 'package:seek_player/core/backup/link_choice.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 連結 Google Drive 後發現雲端已有備份:問使用者要用雲端備份覆寫本機,
/// 還是保留本機資料覆寫雲端。兩者都會覆蓋一方,因此不可點外面關閉,
/// 一定要選一個。
Future<LinkChoice> showCloudBackupFoundDialog(BuildContext context) async {
  final choice = await showDialog<LinkChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: CloudBackupFoundDialog(),
    ),
  );
  // 不可關閉,理論上不會是 null;保險起見預設保留本機,至少不會清掉
  // 使用者眼前的資料。
  return choice ?? LinkChoice.keepLocal;
}

/// 「選擇備份資料」對話框。預設只顯示說明與兩個按鈕;
/// 點「更多」箭頭可展開「備份包含:設定、播放清單、聆聽統計、歌詞」。
class CloudBackupFoundDialog extends StatefulWidget {
  const CloudBackupFoundDialog({super.key});

  @override
  State<CloudBackupFoundDialog> createState() => _CloudBackupFoundDialogState();
}

class _CloudBackupFoundDialogState extends State<CloudBackupFoundDialog> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = [
      l10n.backup_item_settings,
      l10n.backup_item_playlists,
      l10n.backup_item_statistics,
      l10n.backup_item_lyrics,
    ];

    return AlertDialog(
      title: Text(l10n.backup_cloud_found_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.backup_cloud_found_message),
          const SizedBox(height: 8),
          _MoreToggle(
            label: l10n.backup_cloud_found_more,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.backup_cloud_found_includes,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        for (final item in items)
                          Text('• $item', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, LinkChoice.keepLocal),
          child: Text(l10n.backup_keep_local),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, LinkChoice.useCloud),
          child: Text(l10n.backup_use_cloud),
        ),
      ],
    );
  }
}

/// 「更多」文字 + 向下箭頭,展開時箭頭旋轉 180 度。
class _MoreToggle extends StatelessWidget {
  const _MoreToggle({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more, size: 20, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
