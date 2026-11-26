import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 開啟資料夾篩選表單,列出「全部音訊」與各資料夾(名稱、最新檔案日期、
/// 曲目數),點選即關閉並回傳選擇。
///
/// 回傳 record 以區分「選了全部」(`path` 為 null)與「取消」(整個回 null)。
Future<({String? path})?> showFolderPickerSheet(
  BuildContext context, {
  required List<TrackFolder> folders,
  required int totalCount,
  required DateTime? Function(String? folderPath) latestOf,
  required String? selected,
}) {
  return showModalBottomSheet<({String? path})>(
    context: context,
    showDragHandle: true,
    // 資料夾一多就超過預設 9/16 高度上限;改依內容長高、超出時捲動。
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FolderPickerSheet(
      folders: folders,
      totalCount: totalCount,
      latestOf: latestOf,
      selected: selected,
    ),
  );
}

/// 資料夾篩選表單內容,外觀同 FolderMenuButton 的下拉選單。
class FolderPickerSheet extends StatelessWidget {
  const FolderPickerSheet({
    super.key,
    required this.folders,
    required this.totalCount,
    required this.latestOf,
    required this.selected,
  });

  final List<TrackFolder> folders;
  final int totalCount;
  final DateTime? Function(String? folderPath) latestOf;

  /// 目前選中的資料夾路徑;null 代表全部。
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    Widget item({
      required String? path,
      required String name,
      required int count,
      required IconData icon,
    }) {
      final isSelected = path == selected;
      final latest = latestOf(path);
      return ListTile(
        minTileHeight: 64,
        selected: isSelected,
        leading: Icon(icon, color: Colors.amber, size: 32),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: latest == null ? null : Text(dateFormat.format(latest)),
        trailing: Container(
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
        onTap: () => Navigator.of(context).pop((path: path)),
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          item(
            path: null,
            name: l10n.tools_all_audios,
            count: totalCount,
            icon: Icons.library_music,
          ),
          for (final folder in folders)
            Tooltip(
              message: folder.path,
              child: item(
                path: folder.path,
                name: folder.name,
                count: folder.trackCount,
                icon: Icons.folder,
              ),
            ),
        ],
      ),
    );
  }
}
