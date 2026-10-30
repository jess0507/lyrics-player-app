import 'package:flutter/material.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 本地音樂上方的資料夾篩選列:「全部」加上各資料夾,可橫向捲動。
///
/// 外觀用膠囊形 chip,與其他頁的搜尋等動作按鈕做出區別。
/// [selected] 為 null 代表「全部」。
class LocalMusicFolderBar extends StatelessWidget {
  const LocalMusicFolderBar({
    super.key,
    required this.folders,
    required this.selected,
    required this.onSelected,
  });

  final List<TrackFolder> folders;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          _FolderButton(
            label: l10n.music_folder_all,
            isSelected: selected == null,
            onPressed: () => onSelected(null),
          ),
          for (final folder in folders)
            Tooltip(
              message: folder.path,
              child: _FolderButton(
                label: '${folder.name} (${folder.trackCount})',
                isSelected: selected == folder.path,
                onPressed: () => onSelected(folder.path),
              ),
            ),
        ],
      ),
    );
  }
}

class _FolderButton extends StatelessWidget {
  const _FolderButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  /// 以膠囊形 ChoiceChip 呈現篩選,與其他頁搜尋等方角實心動作按鈕區隔:
  /// 未選中只有外框、選中填 secondaryContainer 並顯示勾號。
  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onPressed(),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
  }
}
