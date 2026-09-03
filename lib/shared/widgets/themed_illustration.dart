import 'package:flutter/material.dart';
import 'package:seek_player/gen/assets.gen.dart';

/// 會跟著主題換色的灰階 SVG 插圖。
///
/// 適用於任何「只用灰階繪製」的 SVG:黑代表 [dark](預設主色)、白代表
/// [light](預設底色),中間灰階為兩者之間的深淺。畫出時用一個
/// [ColorFilter.matrix] 做線性內插,因此同一張圖在不同主題色與
/// light / dark 下都能正確呈現,不需要為每張圖各寫一個 widget。
///
/// 用法:
/// ```dart
/// ThemedIllustration(image: Assets.images.emptyState)
/// ```
class ThemedIllustration extends StatelessWidget {
  const ThemedIllustration({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.dark,
    this.light,
  });

  final SvgGenImage image;
  final double? width;
  final double? height;

  /// 灰階「黑」對應的顏色,預設 [ColorScheme.primary]。
  final Color? dark;

  /// 灰階「白」對應的顏色,預設 [ColorScheme.surface]。
  final Color? light;

  /// 建立把灰階 g(0 = 黑、1 = 白)映射到 `dark + (light - dark) * g` 的矩陣。
  /// 矩陣輸入為 0..255 的通道值,最後一欄的偏移量也以 0..255 計。
  static ColorFilter _tint(Color dark, Color light) {
    List<double> row(double d, double l, int channel) {
      final r = List<double>.filled(5, 0);
      r[channel] = l - d;
      r[4] = d * 255;
      return r;
    }

    return ColorFilter.matrix([
      ...row(dark.r, light.r, 0),
      ...row(dark.g, light.g, 1),
      ...row(dark.b, light.b, 2),
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return image.svg(
      width: width,
      height: height,
      colorFilter: _tint(dark ?? scheme.primary, light ?? scheme.surface),
    );
  }
}
