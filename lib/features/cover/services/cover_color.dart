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

/// 將封面主色正規化為「只保留色相,飽和度 / 明度固定為 100%」的純色。
///
/// 封面主色的明暗與飽和度會隨圖片劇烈變化(從近黑到近白、從鮮豔到灰
/// 濁都有),直接套用會讓漸層在某些曲目過暗、過曝或顯得髒。故只取色相
/// 表達曲目個性,飽和度與明度一律拉滿,得到該色相最鮮明的純色;深 /
/// 淺色主題的明暗差異交由呼叫端的疊加比例處理。
Color normalizeCoverColor(Color color) {
  final hsv = HSVColor.fromColor(color);
  return hsv.withSaturation(1.0).withValue(1.0).toColor();
}
