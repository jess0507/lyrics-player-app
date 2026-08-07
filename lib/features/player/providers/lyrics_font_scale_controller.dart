import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/storage/preferences_service.dart';

/// 歌詞字幕的字體縮放倍率(僅完整播放頁的歌詞視圖,持久化於本機
/// SharedPreferences)。1.0 為基準字級,值夾在 [minScale, maxScale]。
class LyricsFontScaleController extends Notifier<double> {
  static const _key = 'lyrics.fontScale';
  static const double minScale = 0.8;
  static const double maxScale = 1.8;
  static const double defaultScale = 1.0;

  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  double build() {
    final stored = _prefs.getDouble(_key);
    return stored == null ? defaultScale : stored.clamp(minScale, maxScale);
  }

  void setScale(double scale) {
    final clamped = scale.clamp(minScale, maxScale);
    if (clamped == state) return;
    state = clamped;
    _prefs.setDouble(_key, clamped);
  }
}

final lyricsFontScaleProvider =
    NotifierProvider<LyricsFontScaleController, double>(
  LyricsFontScaleController.new,
);
