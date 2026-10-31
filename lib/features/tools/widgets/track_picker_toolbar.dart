import 'package:flutter/material.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具選曲頁清單上方的工具列:左側放資料夾下拉([folderButton]),
/// 右側為搜尋、排序與 [trailing] 三顆以分隔線隔開的按鈕。
class TrackPickerToolbar extends StatelessWidget {
  const TrackPickerToolbar({
    super.key,
    required this.folderButton,
    required this.onSearch,
    required this.onSort,
    required this.trailing,
  });

  final Widget folderButton;
  final VoidCallback onSearch;
  final VoidCallback onSort;

  /// 最右側的按鈕,例如工具選曲頁的「從檔案選擇」、本地音樂頁的重新掃描。
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const divider = SizedBox(height: 20, child: VerticalDivider(width: 8));
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      child: Row(
        children: [
          // 佔滿右側按鈕以外的寬度,名稱過長時由按鈕內部截斷。
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: folderButton,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.music_search,
            onPressed: onSearch,
          ),
          divider,
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: l10n.tools_sort_by,
            onPressed: onSort,
          ),
          divider,
          trailing,
        ],
      ),
    );
  }
}
