import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seek_player/features/cover/services/cover_color.dart';

import '../../helpers/test_image.dart';

/// 兩色在 RGB 各通道的差距皆不超過 [tolerance](PNG 解碼 / 降採樣 /
/// 量化可能帶來微小誤差)。
Matcher closeToColor(Color expected, {int tolerance = 8}) =>
    predicate<Color?>((actual) {
      if (actual == null) return false;
      int ch(double v) => (v * 255).round();
      return (ch(actual.r) - ch(expected.r)).abs() <= tolerance &&
          (ch(actual.g) - ch(expected.g)).abs() <= tolerance &&
          (ch(actual.b) - ch(expected.b)).abs() <= tolerance;
    }, 'color within $tolerance of $expected');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeCoverColor', () {
    const source = Color(0xFFD7A6B2); // 低飽和度的馬卡龍粉

    test('保留色相,飽和度 / 明度拉滿為 100%', () {
      final result = normalizeCoverColor(source);
      final src = HSVColor.fromColor(source);
      final out = HSVColor.fromColor(result);
      // 低飽和度(接近灰)的顏色,RGB 三通道只差幾個刻度,轉回 8-bit 時的
      // 四捨五入會讓色相偏移數度,故色相容差放寬到 5°。
      expect(out.hue, closeTo(src.hue, 5));
      expect(out.saturation, closeTo(1.0, 0.01));
      expect(out.value, closeTo(1.0, 0.01));
    });

    test('不同明度 / 飽和度的同色相輸入,正規化後結果相同', () {
      const darkBlue = Color(0xFF0A1E38);
      const brightBlue = Color(0xFF3C8CFF);
      final a = HSVColor.fromColor(normalizeCoverColor(darkBlue));
      final b = HSVColor.fromColor(normalizeCoverColor(brightBlue));
      expect(a.saturation, closeTo(b.saturation, 0.01));
      expect(a.value, closeTo(b.value, 0.01));
      expect(a.hue, closeTo(b.hue, 3));
    });

    test('已是純色的輸入原樣輸出', () {
      const pure = Color(0xFF00FF00);
      expect(normalizeCoverColor(pure).toARGB32(), pure.toARGB32());
    });

    test('近黑 / 近白封面不會造成過暗或過曝', () {
      for (final extreme in const [Color(0xFF000000), Color(0xFFFFFFFF)]) {
        final out = HSVColor.fromColor(normalizeCoverColor(extreme));
        expect(out.saturation, closeTo(1.0, 0.01), reason: '$extreme');
        expect(out.value, closeTo(1.0, 0.01), reason: '$extreme');
      }
    });

    test('透明度原樣保留(取色結果本就不透明,函式不另行處理 alpha)', () {
      expect(
        normalizeCoverColor(const Color(0x80FF0000)).a,
        closeTo(0.5, 0.01),
      );
      expect(normalizeCoverColor(const Color(0xFFFF0000)).a, 1.0);
    });
  });

  group('extractCoverColor', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cover_color_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('純色封面 → 主色即該顏色', () async {
      const red = Color(0xFFD62828);
      final file = await writeSolidColorPng('${tempDir.path}/red.png', red);

      final color = await extractCoverColor(file);

      expect(color, closeToColor(red));
    });

    test('大圖會先降採樣,仍能正確取色', () async {
      const green = Color(0xFF2A9D8F);
      final file = await writeSolidColorPng(
        '${tempDir.path}/big.png',
        green,
        width: 1200,
        height: 1200,
      );

      final color = await extractCoverColor(file);

      expect(color, closeToColor(green));
    });

    test('圖檔不存在 → null', () async {
      final color = await extractCoverColor(File('${tempDir.path}/none.png'));
      expect(color, isNull);
    });

    test('無法解碼的內容 → null', () async {
      final file = File('${tempDir.path}/garbage.png');
      await file.writeAsString('not an image');

      final color = await extractCoverColor(file);

      expect(color, isNull);
    });
  });
}
