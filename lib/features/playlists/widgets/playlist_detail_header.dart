import 'package:flutter/material.dart';

/// 播放清單詳細頁內容頂端:靠左的清單名稱,下方一列操作按鈕
/// ([actions],例如新增 / 編輯 / 排序 / 搜尋),同一列最右側放 [trailing](例如隨機 / 播放按鈕)。
class PlaylistDetailHeader extends StatelessWidget {
  const PlaylistDetailHeader({
    super.key,
    required this.title,
    required this.actions,
    this.trailing,
  });

  final String title;
  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actions.isNotEmpty || trailing != null)
          Padding(
            // 左側按鈕縮成 compact(32 見方、圖示 20),圖示距按鈕邊緣 6,
            // 左側補 10 讓圖示與標題文字對齊。
            padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 16, 4),
            child: Row(
              children: [
                IconButtonTheme(
                  data: IconButtonThemeData(
                    style: IconButton.styleFrom(
                      iconSize: 22,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
      ],
    );
  }
}
