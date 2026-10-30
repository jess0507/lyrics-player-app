import 'package:flutter/material.dart';
import 'package:seek_player/gen/assets.gen.dart';

/// 頂欄左側沒有按鈕(分頁根頁)時放在 [AppBar.leading] 的 app 圖示,仿 VLC。
///
/// 淺色主題用黑線版 logo、深色主題用白線版,避免線條與底色融在一起。
class AppLogoLeading extends StatelessWidget {
  const AppLogoLeading({super.key});

  /// logo 圖檔四周約有 21% 透明留白,畫 50dp 時實際線條約 29dp 高,
  /// 與 VLC 頂欄圖示的視覺大小相近;仍落在 AppBar 預設 56dp 的 leading 寬度內。
  static const double _size = 50;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = isDark ? Assets.icon.appLogoDark : Assets.icon.appLogoPng;
    return Center(
      child: logo.image(
        width: _size,
        height: _size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
