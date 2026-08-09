import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/storage/preferences_service.dart';

/// 歌詞的水平對齊方式(左 / 中 / 右)。
/// 刻意用 left / right 而非 start / end:使用者選的是視覺位置,
/// 不隨語系書寫方向翻轉。
enum LyricsTextAlign {
  left,
  center,
  right;

  TextAlign get textAlign => switch (this) {
    left => TextAlign.left,
    center => TextAlign.center,
    right => TextAlign.right,
  };

  IconData get icon => switch (this) {
    left => Icons.format_align_left,
    center => Icons.format_align_center,
    right => Icons.format_align_right,
  };
}

/// 歌詞字幕的對齊方式(僅完整播放頁的歌詞視圖,持久化於本機
/// SharedPreferences)。預設置左。
class LyricsTextAlignController extends Notifier<LyricsTextAlign> {
  static const _key = 'lyrics.textAlign';
  static const LyricsTextAlign defaultAlign = LyricsTextAlign.left;

  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  LyricsTextAlign build() {
    final stored = _prefs.getString(_key);
    // 舊版或毀損的值一律回預設,不讓解析失敗擋住歌詞顯示。
    return LyricsTextAlign.values.firstWhere(
      (align) => align.name == stored,
      orElse: () => defaultAlign,
    );
  }

  void setAlign(LyricsTextAlign align) {
    if (align == state) return;
    state = align;
    _prefs.setString(_key, align.name);
  }
}

final lyricsTextAlignProvider =
    NotifierProvider<LyricsTextAlignController, LyricsTextAlign>(
      LyricsTextAlignController.new,
    );
