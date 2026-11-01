import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

/// 頂欄左側沒有按鈕(分頁根頁)時放在 [AppBar.leading] 的 app 圖示,仿 VLC。
///
/// 用 SVG 版 logo 並依 theme 換色:音符換成使用者選的種子色
/// ([AppColorSeed.color],比 fromSeed 推導的 primary 鮮豔);單色主題的種子
/// 是固定灰,深色模式下看不清,改用隨亮度翻轉的 [ColorScheme.primary]。
/// 橫線換成 [ColorScheme.onSurface],淺色主題黑、深色主題白,
/// 避免線條與底色融在一起。
class AppLogoLeading extends ConsumerWidget {
  const AppLogoLeading({super.key});

  /// SVG 四周留白比 PNG 少(圖形約佔 84% 寬,PNG 約 57%),畫 34dp 時
  /// 實際線條約 29dp 寬,與原本 50dp 的 PNG 視覺大小一致,也與 VLC 頂欄
  /// 圖示相近;落在 AppBar 預設 56dp 的 leading 寬度內。
  static const double _size = 34;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final seed = ref.watch(
      settingsControllerProvider.select((s) => s.seedColor),
    );
    return Center(
      child: Assets.icon.appLogoSvg.svg(
        width: _size,
        height: _size,
        colorMapper: _LogoColorMapper(
          note: seed.isMono ? scheme.primary : seed.color,
          lines: scheme.onSurface,
        ),
      ),
    );
  }
}

/// 把 `app_logo.svg` 寫死的顏色換成 theme 色:綠色音符(#00DB00)→ [note],
/// 黑色橫線(#000000)→ [lines]。
class _LogoColorMapper extends ColorMapper {
  const _LogoColorMapper({required this.note, required this.lines});

  static const _svgNote = Color(0xFF00DB00);
  static const _svgLines = Color(0xFF000000);

  final Color note;
  final Color lines;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == _svgNote) return note;
    if (color == _svgLines) return lines;
    return color;
  }

  // 顏色變了要重新解析 SVG,否則切換 theme 時會沿用快取的舊顏色。
  @override
  bool operator ==(Object other) =>
      other is _LogoColorMapper && other.note == note && other.lines == lines;

  @override
  int get hashCode => Object.hash(note, lines);
}
