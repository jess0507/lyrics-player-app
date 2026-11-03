import 'package:flutter/material.dart';

/// 清單頁的操作列:左側一排 compact 圖示按鈕([actions],例如新增 / 編輯 /
/// 排序 / 搜尋),最右側放 [trailing](例如隨機 / 播放按鈕)。
class PlaylistActionBar extends StatelessWidget {
  const PlaylistActionBar({super.key, required this.actions, this.trailing});

  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 左側按鈕縮成 compact(32 見方),圖示距按鈕邊緣約 6,
      // 左側補 10 讓圖示與上方標題文字對齊。
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
    );
  }
}
