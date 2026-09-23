import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:seek_player/core/crash_reporter.dart';

/// 從封面圖檔以 [PaletteGenerator] 抽出主色;圖檔遺失 / 無法解碼等任何
/// 失敗皆回 null(best-effort,呼叫端據此退回主題色)。
///
/// 為避免大圖造成前景卡頓:
/// 1. 先以 [ui.instantiateImageCodec] 把圖**降採樣**到約 100px(取主色不需
///    高解析,像素數可少上千倍),解碼由引擎負責、不佔 Dart UI 執行緒。
/// 2. 再把降採樣後的 RGBA bytes 丟到背景 isolate([Isolate.run])執行純 Dart
///    的色彩量化,主 isolate(UI)完全不做這段重運算。
Future<Color?> extractCoverColor(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 100,
      targetHeight: 100,
    );
    final image = (await codec.getNextFrame()).image;
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData();
    image.dispose();
    codec.dispose();
    if (byteData == null) return null;

    // fromByteData 為純 Dart 運算,可在背景 isolate 安全執行(不需引擎)。
    final argb = await Isolate.run<int?>(() async {
      final encoded = EncodedImage(byteData, width: width, height: height);
      // 預設濾鏡會丟掉近黑 / 近白像素,避免彩色封面的黑邊或白底搶走主色。
      final palette = await PaletteGenerator.fromByteData(
        encoded,
        maximumColorCount: 16,
      );
      final dominant = palette.dominantColor;
      // 通過濾鏡的像素總數(各色 population 即像素數);佔比太低代表封面
      // 幾乎全黑 / 全白,只剩小 logo 或文字有顏色,主色不足以代表整張圖。
      final coloredPixels = palette.paletteColors.fold<int>(
        0,
        (sum, c) => sum + c.population,
      );
      final coloredShare = coloredPixels / (width * height);
      if (dominant != null && coloredShare >= minColoredPixelShare) {
        return dominant.color.toARGB32();
      }
      // 整張圖幾乎都被濾掉,代表封面本身就是黑底 / 白底;改以不加濾鏡
      // 重新取色,主色即黑 / 白,由 [normalizeCoverColor] 呈現為灰色漸層,
      // 而非讓小面積的彩色搶走主色或退回主題色。
      final unfiltered = await PaletteGenerator.fromByteData(
        encoded,
        maximumColorCount: 16,
        filters: const <PaletteFilter>[],
      );
      return unfiltered.dominantColor?.color.toARGB32();
    });
    return argb == null ? null : Color(argb);
  } catch (e, s) {
    reportError(e, s, reason: '封面取色失敗，退回主題色');
    return null;
  }
}

/// 將封面主色正規化為「只保留色相」的純色;飽和度 / 明度依主題明暗固定。
///
/// 封面主色的明暗與飽和度會隨圖片劇烈變化(從近黑到近白、從鮮豔到灰
/// 濁都有),直接套用會讓漸層在某些曲目過暗、過曝或顯得髒。故只取色相
/// 表達曲目個性,飽和度與明度一律固定,讓不同封面得到一致的鮮明度。
///
/// 兩種主題各自有一組常數,可獨立微調:
/// - [Brightness.dark](預設):[darkModeSaturation] / [darkModeValue]。
///   深色 surface 上需要足夠亮度才看得出色彩,但拉滿 100% 仍會刺眼,故
///   略為壓低。
/// - [Brightness.light]:[lightModeSaturation] / [lightModeValue]。純色疊
///   在近白的 surface 上更容易刺眼,故明度壓得比深色主題更低。
///
/// 灰階封面(黑 / 白 / 灰,飽和度低於 [grayscaleSaturationThreshold])
/// 沒有有意義的色相(HSV 會回 0°,若照常套飽和度會變成鮮紅),故保持
/// 飽和度 0,只套用主題明度,呈現為灰色漸層。近白但略帶暖色的米白 /
/// 奶油色(明度 ≥ [nearWhiteMinValue] 且飽和度 < [nearWhiteMaxSaturation])
/// 視覺上仍是「白色封面」,同樣視為灰階,否則會被放大成黃色漸層。
///
/// HSV 的明度並非感知亮度:同樣的飽和度 / 明度,綠、黃、青的相對亮度
/// 是藍、紅的數倍,固定明度後仍會刺眼(例如黑底綠 logo 的封面)。故最後
/// 再以 [Color.computeLuminance] 檢查,超過主題的亮度上限
/// ([darkModeMaxLuminance] / [lightModeMaxLuminance])才把明度往下壓到
/// 剛好符合上限;未超過的色相(藍、紅、紫等)完全不動。
Color normalizeCoverColor(
  Color color, {
  Brightness brightness = Brightness.dark,
}) {
  final hsv = HSVColor.fromColor(color);
  final (saturation, value, maxLuminance) = switch (brightness) {
    Brightness.dark => (
      darkModeSaturation,
      darkModeValue,
      darkModeMaxLuminance,
    ),
    Brightness.light => (
      lightModeSaturation,
      lightModeValue,
      lightModeMaxLuminance,
    ),
  };
  final isNearWhite =
      hsv.value >= nearWhiteMinValue && hsv.saturation < nearWhiteMaxSaturation;
  final isGrayscale =
      hsv.saturation < grayscaleSaturationThreshold || isNearWhite;
  final normalized = hsv
      .withSaturation(isGrayscale ? 0.0 : saturation)
      .withValue(value);
  return _capLuminance(normalized, maxLuminance);
}

/// 若 [hsv] 的相對亮度超過 [maxLuminance],降低明度(保留色相與飽和度)
/// 直到不超過為止;未超過則原樣輸出。
///
/// sRGB 的相對亮度約與各通道線性縮放係數的 2.2 次方成正比,故可由
/// `(max / lum) ^ (1 / 2.2)` 一次估出明度縮放比;因 sRGB 轉換曲線並非
/// 純冪次(暗部有線性段),再迭代幾次修正殘差。
Color _capLuminance(HSVColor hsv, double maxLuminance) {
  var current = hsv;
  var color = current.toColor();
  for (var i = 0; i < 4; i++) {
    final lum = color.computeLuminance();
    if (lum <= maxLuminance) break;
    final scale = math.pow(maxLuminance / lum, 1 / 2.2).toDouble();
    current = current.withValue(current.value * scale);
    color = current.toColor();
  }
  return color;
}

/// 封面主色的飽和度低於此值即視為灰階(黑 / 白 / 灰),不套用色相;
/// 見 [normalizeCoverColor]。門檻略高於 0 以容忍 JPEG 壓縮與量化造成的
/// 微小偏色。
const double grayscaleSaturationThreshold = 0.1;

/// 封面主色明度達此值且飽和度低於 [nearWhiteMaxSaturation] 即視為近白
/// (米白 / 奶油色),當作灰階處理;見 [normalizeCoverColor]。
const double nearWhiteMinValue = 0.9;

/// 近白判定的飽和度上限;見 [nearWhiteMinValue]。粉彩色(飽和度約 0.3
/// 起)不在此列,仍保留色相。
const double nearWhiteMaxSaturation = 0.25;

/// 通過近黑 / 近白濾鏡的像素佔全圖比例至少要達此值,濾鏡後的主色才算
/// 代表整張封面;低於此值視為黑底 / 白底封面,改取未濾鏡的主色(黑 /
/// 白),呈現為灰階漸層。見 [extractCoverColor]。
const double minColoredPixelShare = 0.2;

/// 深色主題下封面色的明度(HSV value);見 [normalizeCoverColor]。
const double darkModeValue = 0.85;

/// 深色主題下封面色的飽和度;見 [normalizeCoverColor]。
const double darkModeSaturation = 0.9;

/// 淺色主題下封面色的明度(HSV value);見 [normalizeCoverColor]。
const double lightModeValue = 0.72;

/// 淺色主題下封面色的飽和度;見 [normalizeCoverColor]。
const double lightModeSaturation = 0.9;

/// 深色主題下封面色的相對亮度上限([Color.computeLuminance],0~1);
/// 見 [normalizeCoverColor]。以 [darkModeSaturation] / [darkModeValue] 而言,
/// 藍約 0.06、紅約 0.15、紫紅約 0.20、橙約 0.28、綠約 0.50、黃約 0.64,
/// 故此值不影響藍 / 紅,紫紅略壓,綠 / 黃 / 青 / 橙等高亮色相壓得較多
/// (綠約壓到明度 0.53)。
const double darkModeMaxLuminance = 0.18;

/// 淺色主題下封面色的相對亮度上限;見 [normalizeCoverColor]。淺色主題的
/// 明度本已壓低([lightModeValue]),紅約 0.11、橙約 0.20、綠約 0.34、
/// 黃約 0.44,故此值只壓綠 / 黃 / 青。
const double lightModeMaxLuminance = 0.25;
