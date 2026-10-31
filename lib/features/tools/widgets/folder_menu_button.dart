import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具選曲頁左上的資料夾下拉:顯示目前資料夾名稱 + 箭頭,
/// 展開後列出「全部音訊」與各資料夾(名稱、最新檔案日期、曲目數)。
/// [selected] 為 null 代表全部。
class FolderMenuButton extends StatelessWidget {
  const FolderMenuButton({
    super.key,
    required this.folders,
    required this.totalCount,
    required this.latestOf,
    required this.selected,
    required this.onSelected,
  });

  final List<TrackFolder> folders;
  final int totalCount;

  /// 回傳資料夾(null 為全部)內最新檔案的時間;未知回 null。
  final DateTime? Function(String? folderPath) latestOf;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedName = selected == null
        ? l10n.tools_all_audios
        : folders.firstWhere((f) => f.path == selected).name;

    Widget item({
      required String? path,
      required String name,
      required int count,
      required IconData icon,
    }) {
      final isSelected = path == selected;
      final latest = latestOf(path);
      return MenuItemButton(
        onPressed: () => onSelected(path),
        leadingIcon: Icon(icon, color: Colors.amber, size: 32),
        trailingIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isSelected
                  ? theme.colorScheme.surface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(280, 64),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, end: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.bodyLarge),
              if (latest != null)
                Text(
                  DateFormat.yMd(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(latest),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return MenuAnchor(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      menuChildren: [
        item(
          path: null,
          name: l10n.tools_all_audios,
          count: totalCount,
          icon: Icons.library_music,
        ),
        for (final folder in folders)
          item(
            path: folder.path,
            name: folder.name,
            count: folder.trackCount,
            icon: Icons.folder,
          ),
      ],
      builder: (context, controller, _) => TextButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          textStyle: theme.textTheme.titleMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 依工具列剩餘寬度截斷,避免長資料夾名稱溢出。
            Flexible(
              child: Text(
                selectedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              controller.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            ),
          ],
        ),
      ),
    );
  }
}
