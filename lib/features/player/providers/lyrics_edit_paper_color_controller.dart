import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/player/models/lyrics_paper_color.dart';

/// 編輯歌詞頁的背景顏色(持久化於本機 SharedPreferences)。
class LyricsEditPaperColorController extends Notifier<LyricsPaperColor> {
  static const _key = 'lyrics.editPaperColor';

  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  LyricsPaperColor build() => LyricsPaperColor.fromName(_prefs.getString(_key));

  void setColor(LyricsPaperColor color) {
    if (color == state) return;
    state = color;
    _prefs.setString(_key, color.name);
  }
}

final lyricsEditPaperColorProvider =
    NotifierProvider<LyricsEditPaperColorController, LyricsPaperColor>(
      LyricsEditPaperColorController.new,
    );
