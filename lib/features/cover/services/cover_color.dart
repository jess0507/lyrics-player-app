import 'dart:io';
import 'dart:isolate';
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
      if (dominant != null) return dominant.color.toARGB32();
      // 整張圖都被濾掉,代表封面本身就是純黑 / 純白(或極接近);改以不加
      // 濾鏡重新取色,讓這類封面得到灰階主色,由 [normalizeCoverColor]
      // 呈現為灰色漸層,而非退回主題色。
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
/// 飽和度 0,只套用主題明度,呈現為灰色漸層。
Color normalizeCoverColor(
  Color color, {
  Brightness brightness = Brightness.dark,
}) {
  final hsv = HSVColor.fromColor(color);
  final (saturation, value) = switch (brightness) {
    Brightness.dark => (darkModeSaturation, darkModeValue),
    Brightness.light => (lightModeSaturation, lightModeValue),
  };
  final isGrayscale = hsv.saturation < grayscaleSaturationThreshold;
  return hsv
      .withSaturation(isGrayscale ? 0.0 : saturation)
      .withValue(value)
      .toColor();
}

/// 封面主色的飽和度低於此值即視為灰階(黑 / 白 / 灰),不套用色相;
/// 見 [normalizeCoverColor]。門檻略高於 0 以容忍 JPEG 壓縮與量化造成的
/// 微小偏色。
const double grayscaleSaturationThreshold = 0.1;

/// 深色主題下封面色的明度(HSV value);見 [normalizeCoverColor]。
const double darkModeValue = 0.85;

/// 深色主題下封面色的飽和度;見 [normalizeCoverColor]。
const double darkModeSaturation = 0.9;

/// 淺色主題下封面色的明度(HSV value);見 [normalizeCoverColor]。
const double lightModeValue = 0.72;

/// 淺色主題下封面色的飽和度;見 [normalizeCoverColor]。
const double lightModeSaturation = 0.9;
