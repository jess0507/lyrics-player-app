import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/storage/preferences_service.dart';

/// 編輯歌詞頁文字框的字級(邏輯像素,持久化於本機 SharedPreferences)。
/// 與播放頁歌詞字級倍率(`lyricsFontScaleProvider`)分開設定。
class LyricsEditFontSizeController extends Notifier<double> {
  static const _key = 'lyrics.editFontSize';
  static const double minSize = 12;
  static const double maxSize = 32;
  static const double defaultSize = 16;

  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  double build() {
    final stored = _prefs.getDouble(_key);
    return stored == null ? defaultSize : stored.clamp(minSize, maxSize);
  }

  void setSize(double size) {
    final clamped = size.roundToDouble().clamp(minSize, maxSize);
    if (clamped == state) return;
    state = clamped;
    _prefs.setDouble(_key, clamped);
  }
}

final lyricsEditFontSizeProvider =
    NotifierProvider<LyricsEditFontSizeController, double>(
      LyricsEditFontSizeController.new,
    );
