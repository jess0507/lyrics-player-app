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

    test('深色主題(預設):保留色相,飽和度 / 明度固定為深色常數', () {
      final result = normalizeCoverColor(source);
      final src = HSVColor.fromColor(source);
      final out = HSVColor.fromColor(result);
      // 低飽和度(接近灰)的顏色,RGB 三通道只差幾個刻度,轉回 8-bit 時的
      // 四捨五入會讓色相偏移數度,故色相容差放寬到 5°。
      expect(out.hue, closeTo(src.hue, 5));
      expect(out.saturation, closeTo(darkModeSaturation, 0.01));
      expect(out.value, closeTo(darkModeValue, 0.01));
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

    test('淺色主題:保留色相,明度壓到 lightModeValue、飽和度略降', () {
      final result = normalizeCoverColor(source, brightness: Brightness.light);
      final src = HSVColor.fromColor(source);
      final out = HSVColor.fromColor(result);
      expect(out.hue, closeTo(src.hue, 5));
      expect(out.saturation, closeTo(lightModeSaturation, 0.01));
      expect(out.value, closeTo(lightModeValue, 0.01));
      // 淺色主題的結果必須比深色主題暗,才不會在近白 surface 上刺眼。
      final dark = HSVColor.fromColor(
        normalizeCoverColor(source, brightness: Brightness.dark),
      );
      expect(out.value, lessThan(dark.value));
    });

    test('已符合深色常數且亮度未超上限的輸入原樣輸出', () {
      final pure = HSVColor.fromAHSV(
        1.0,
        240, // 藍:同樣 S / V 下相對亮度最低,不會被亮度上限壓暗
        darkModeSaturation,
        darkModeValue,
      ).toColor();
      expect(normalizeCoverColor(pure).toARGB32(), pure.toARGB32());
    });

    test('綠 / 黃 / 青等高亮色相:壓低明度至亮度上限,色相 / 飽和度保留', () {
      for (final hue in const [60.0, 120.0, 180.0]) {
        final source = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

        final dark = normalizeCoverColor(source);
        final darkHsv = HSVColor.fromColor(dark);
        expect(darkHsv.hue, closeTo(hue, 3), reason: 'hue $hue dark');
        expect(
          darkHsv.saturation,
          closeTo(darkModeSaturation, 0.02),
          reason: 'hue $hue dark',
        );
        expect(darkHsv.value, lessThan(darkModeValue), reason: 'hue $hue dark');
        expect(
          dark.computeLuminance(),
          lessThanOrEqualTo(darkModeMaxLuminance + 0.01),
          reason: 'hue $hue dark',
        );

        final light = normalizeCoverColor(source, brightness: Brightness.light);
        expect(
          light.computeLuminance(),
          lessThanOrEqualTo(lightModeMaxLuminance + 0.01),
          reason: 'hue $hue light',
        );
      }
    });

    test('黑底綠 logo 這類封面取到的鮮綠,深色主題下不再刺眼', () {
      const vividGreen = Color(0xFF00D000);
      final before = HSVColor.fromAHSV(
        1.0,
        120,
        darkModeSaturation,
        darkModeValue,
      ).toColor();
      final out = normalizeCoverColor(vividGreen);
      expect(out.computeLuminance(), lessThan(before.computeLuminance() / 1.5));
      expect(HSVColor.fromColor(out).hue, closeTo(120, 3));
    });

    test('藍 / 紅等低亮度色相:亮度未超上限,明度維持主題常數', () {
      for (final hue in const [0.0, 240.0]) {
        final source = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
        final dark = HSVColor.fromColor(normalizeCoverColor(source));
        expect(dark.value, closeTo(darkModeValue, 0.01), reason: 'hue $hue');
        final light = HSVColor.fromColor(
          normalizeCoverColor(source, brightness: Brightness.light),
        );
        expect(light.value, closeTo(lightModeValue, 0.01), reason: 'hue $hue');
      }
    });

    test('黑 / 白 / 灰封面 → 飽和度 0 的灰色,亮度不超過主題上限', () {
      for (final gray in const [
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0xFF808080),
        Color(0xFF1A1A1A),
      ]) {
        final dark = normalizeCoverColor(gray);
        expect(HSVColor.fromColor(dark).saturation, 0.0, reason: '$gray');
        expect(
          dark.computeLuminance(),
          closeTo(darkModeMaxLuminance, 0.01),
          reason: '$gray',
        );

        final light = normalizeCoverColor(gray, brightness: Brightness.light);
        expect(HSVColor.fromColor(light).saturation, 0.0, reason: '$gray');
        expect(
          light.computeLuminance(),
          closeTo(lightModeMaxLuminance, 0.01),
          reason: '$gray',
        );
      }
    });

    test('米白 / 奶油色的白色封面視為灰階,不會變成黃色', () {
      for (final cream in const [
        Color(0xFFF5EED8), // 奶油色,飽和度約 0.12
        Color(0xFFFAF0E6), // 亞麻白
        Color(0xFFFFF8DC), // 玉米絲色,飽和度約 0.14
      ]) {
        final dark = normalizeCoverColor(cream);
        expect(HSVColor.fromColor(dark).saturation, 0.0, reason: '$cream');
        expect(
          dark.toARGB32(),
          normalizeCoverColor(const Color(0xFFFFFFFF)).toARGB32(),
          reason: '$cream',
        );
        final light = normalizeCoverColor(cream, brightness: Brightness.light);
        expect(HSVColor.fromColor(light).saturation, 0.0, reason: '$cream');
      }
    });

    test('明亮的粉彩色(飽和度達近白上限)仍保留色相', () {
      final pastel = HSVColor.fromAHSV(
        1.0,
        350,
        nearWhiteMaxSaturation + 0.05,
        1.0,
      ).toColor();
      final out = HSVColor.fromColor(normalizeCoverColor(pastel));
      expect(out.hue, closeTo(350, 5));
      expect(out.saturation, closeTo(darkModeSaturation, 0.02));
    });

    test('略帶偏色的灰(飽和度低於門檻)仍視為灰階,不會變成紅色', () {
      // JPEG 壓縮 / 量化常讓灰階封面帶一點偏色,飽和度約 0.02~0.05。
      const tintedGray = Color(0xFF848080); // 飽和度約 0.03
      final out = normalizeCoverColor(tintedGray);
      expect(HSVColor.fromColor(out).saturation, 0.0);
      expect(
        out.toARGB32(),
        normalizeCoverColor(const Color(0xFF808080)).toARGB32(),
      );
    });

    test('飽和度達門檻的低彩度色仍保留色相並套用主題飽和度', () {
      final source = HSVColor.fromAHSV(
        1.0,
        200,
        grayscaleSaturationThreshold + 0.05,
        0.6,
      ).toColor();
      final out = HSVColor.fromColor(normalizeCoverColor(source));
      expect(out.hue, closeTo(200, 5));
      expect(out.saturation, closeTo(darkModeSaturation, 0.01));
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

    test('純黑封面 → 主色為黑(不因濾鏡而退回 null)', () async {
      const black = Color(0xFF000000);
      final file = await writeSolidColorPng('${tempDir.path}/black.png', black);

      final color = await extractCoverColor(file);

      expect(color, closeToColor(black));
    });

    test('純白封面 → 主色為白(不因濾鏡而退回 null)', () async {
      const white = Color(0xFFFFFFFF);
      final file = await writeSolidColorPng('${tempDir.path}/white.png', white);

      final color = await extractCoverColor(file);

      expect(color, closeToColor(white));
    });

    test('白底 + 小面積彩色 logo → 主色為白(不被 logo 搶走)', () async {
      final file = await writeTwoTonePng(
        '${tempDir.path}/white_logo.png',
        background: const Color(0xFFFFFFFF),
        accent: const Color(0xFF00D000),
        accentShare: 0.1,
      );

      final color = await extractCoverColor(file);

      expect(color, closeToColor(const Color(0xFFFFFFFF)));
    });

    test('黑底 + 小面積彩色 logo → 主色為黑', () async {
      final file = await writeTwoTonePng(
        '${tempDir.path}/black_logo.png',
        background: const Color(0xFF000000),
        accent: const Color(0xFF00D000),
        accentShare: 0.1,
      );

      final color = await extractCoverColor(file);

      expect(color, closeToColor(const Color(0xFF000000)));
    });

    test('白底 + 大面積彩色主體 → 主色為該顏色', () async {
      const blue = Color(0xFF1E5AC8);
      final file = await writeTwoTonePng(
        '${tempDir.path}/white_big.png',
        background: const Color(0xFFFFFFFF),
        accent: blue,
        accentShare: 0.5,
      );

      final color = await extractCoverColor(file);

      expect(color, closeToColor(blue));
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
