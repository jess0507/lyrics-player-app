import 'package:flutter/material.dart';

/// 播放清單詳細頁內容頂端:靠左的清單名稱,下方一列操作按鈕
/// ([actions],例如新增 / 編輯 / 排序 / 搜尋),各按鈕以分隔線隔開。
class PlaylistDetailHeader extends StatelessWidget {
  const PlaylistDetailHeader({
    super.key,
    required this.title,
    required this.actions,
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const divider = SizedBox(height: 20, child: VerticalDivider(width: 8));
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
        if (actions.isNotEmpty)
          Padding(
            // 按鈕本身有 8 的內距,左側只補 8 讓圖示與標題文字對齊。
            padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) divider,
                  actions[i],
                ],
              ],
            ),
          ),
      ],
    );
  }
}
