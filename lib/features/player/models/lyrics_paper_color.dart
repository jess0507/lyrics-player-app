import 'package:flutter/material.dart';

/// 編輯歌詞頁的背景(紙張)顏色。[system] 跟隨主題;其餘為淺色紙張,
/// 文字一律用深色以確保在深色主題下仍可讀。
enum LyricsPaperColor {
  system(null),
  white(Color(0xFFFFFFFF)),
  gray(Color(0xFFF3F3F3)),
  cream(Color(0xFFFDF6E3)),
  peach(Color(0xFFFBEFE6)),
  blue(Color(0xFFEAF3FD));

  const LyricsPaperColor(this.color);

  /// null 為跟隨主題背景。
  final Color? color;

  /// 紙張上的文字顏色;跟隨主題時回 null(用主題預設)。
  Color? get textColor => color == null ? null : const Color(0xDD000000);

  static LyricsPaperColor fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return system;
  }
}
