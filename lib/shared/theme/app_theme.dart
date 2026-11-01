import 'package:flutter/material.dart';

/// 可供使用者選擇的主題種子色。
///
/// 參考 Flutter 官方 material_3_demo 的 `ColorSeed`：每個種子色經
/// [ColorScheme.fromSeed] 推導出完整的 Material 3 配色。
enum AppColorSeed {
  green('Green', Colors.green),
  teal('Teal', Colors.teal),
  blue('Blue', Colors.blue),
  indigo('Indigo', Color(0xFF3D5AFE)),
  purple('Purple', Colors.purple),
  pink('Pink', Colors.pink),
  red('Red', Colors.red),
  deepOrange('Deep Orange', Colors.deepOrange),
  brown('Brown', Colors.brown),
  orange('Orange', Colors.orange),
  yellow('Yellow', Colors.yellow),

  /// 單色主題:淺色模式主色為灰、深色模式主色為近白,隨亮度翻轉。
  mono('Grey', Color(0xFF5F6368), isMono: true);

  const AppColorSeed(this.label, this.color, {this.isMono = false});

  final String label;
  final Color color;

  /// 是否為單色(灰 / 白)主題,需特殊建構而非走 [ColorScheme.fromSeed]。
  final bool isMono;

  /// 預設種子色（沿用改版前的藍色）。
  static const AppColorSeed defaultSeed = AppColorSeed.green;

  static AppColorSeed fromName(String? name) {
    return values.firstWhere((s) => s.name == name, orElse: () => defaultSeed);
  }
}

/// 集中管理深 / 淺色主題。
class AppTheme {
  AppTheme._();

  static ThemeData light(AppColorSeed seed) => _build(Brightness.light, seed);
  static ThemeData dark(AppColorSeed seed) => _build(Brightness.dark, seed);

  static ThemeData _build(Brightness brightness, AppColorSeed seed) {
    final scheme = seed.isMono
        ? _monoScheme(brightness)
        : ColorScheme.fromSeed(seedColor: seed.color, brightness: brightness);
    final theme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // 捲動時不讓 AppBar 疊上 surfaceTint 色調:elevation 歸零、tint 透明。
      // 否則內容捲到 AppBar 下方時頂部會出現變色帶,與 body 的純色 / 漸層
      // 背景產生分界(尤其播放頁的透明 AppBar 疊在漸層上會被切斷)。
      appBarTheme: AppBarTheme(
        centerTitle: false,
        // 返回鍵佔 56px 寬、箭頭置中,右側已留 16px;預設 titleSpacing 再加
        // 16px 會讓箭頭與標題離太遠。改為 0;分頁根頁以 AppLogoLeading 佔同一個位置,間距一致。
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      // FAB 仿 VLC 播放鍵:圓形、56dp,顏色用 M3 預設;icon 放大到 36dp,
      // play_arrow 的三角形在 24 格內約佔 13 格高,放大後約 20dp,
      // 與 VLC 圖形約佔直徑 38% 的比例一致。
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
        sizeConstraints: BoxConstraints.tightFor(width: 56, height: 56),
        iconSize: 36,
      ),
    );
    // 底部導覽需要 theme 的 textTheme(label 沿用預設 labelMedium),故建完再補上。
    return theme.copyWith(
      navigationBarTheme: _navigationBarTheme(scheme, theme.textTheme),
    );
  }

  /// 底部導覽:選中項不畫指示器底色;去掉 label 預設的 top 4px,讓 icon
  /// 與文字更貼近。顏色照 M3 預設(`_NavigationBarDefaultsM3`),只把未選中色
  /// 改為 90% 不透明。theme 的 iconTheme / labelTextStyle 會整個取代預設值、
  /// 不會合併,所以選中 / 停用狀態也得照預設值寫回。
  static NavigationBarThemeData _navigationBarTheme(
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final unselected = scheme.onSurfaceVariant.withValues(alpha: 0.8);
    final disabled = scheme.onSurfaceVariant.withValues(alpha: 0.38);
    return NavigationBarThemeData(
      indicatorColor: Colors.transparent,
      labelPadding: EdgeInsets.zero,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.disabled)
              ? disabled
              : states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : unselected,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium!.apply(
          color: states.contains(WidgetState.disabled)
              ? disabled
              : states.contains(WidgetState.selected)
              ? scheme.onSurface
              : unselected,
        ),
      ),
    );
  }

  /// 灰 / 白單色配色:淺色模式主色為灰、深色模式主色為近白。
  ///
  /// 使用 [DynamicSchemeVariant.monochrome] 產生完全無色相的灰階配色,
  /// 避免一般 `fromSeed` 對 grey 種子仍殘留的藍綠色調(會反映在 NavigationBar
  /// 指示器等 container 色上),再把強調色覆寫為偏好的灰 / 近白。
  static ColorScheme _monoScheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final accent = isLight ? const Color(0xFF5F6368) : const Color(0xFFE8EAED);
    final onAccent = isLight ? Colors.white : Colors.black;
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5F6368),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    );
    return base.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      tertiary: accent,
      onTertiary: onAccent,
      inversePrimary: onAccent,
      primaryContainer: isLight ? accent.withAlpha(120) : accent.withAlpha(120),
    );
  }
}
