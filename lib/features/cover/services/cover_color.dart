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
      final palette = await PaletteGenerator.fromByteData(
        EncodedImage(byteData, width: width, height: height),
        maximumColorCount: 16,
      );
      return palette.dominantColor?.color.toARGB32();
    });
    return argb == null ? null : Color(argb);
  } catch (e, s) {
    reportError(e, s, reason: '封面取色失敗，退回主題色');
    return null;
  }
}

/// 深 / 淺色主題下封面色採用的固定明度(HSV value)。
///
/// 封面主色的明暗會隨圖片而劇烈變化(從近黑到近白都有),直接套用會讓
/// 漸層在某些曲目過暗或過曝。故只保留封面色的「色相 / 飽和度」表達曲目
/// 個性,明度則依當前主題固定:淺色主題取較高明度貼近背景、深色主題取
/// 較低明度避免刺眼。
const double _coverValueLight = 0.92;
const double _coverValueDark = 0.55;

/// 將封面主色正規化為「保留色相 / 飽和度、明度固定」的顏色。
///
/// 明度依 [brightness](當前主題)選用 [_coverValueLight] / [_coverValueDark]。
Color normalizeCoverColor(Color color, Brightness brightness) {
  final hsv = HSVColor.fromColor(color);
  final value = brightness == Brightness.dark
      ? _coverValueDark
      : _coverValueLight;
  return hsv.withValue(value).toColor();
}
