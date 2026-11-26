import 'package:flutter/material.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具分頁提供的工具:先選工具、再選曲目,最後開啟該工具的動作表單。
///
/// [name] 同時作為選曲頁的路由片段(`/tools/lyrics`、`/tools/lyricsEdit`、`/tools/cover`)。
/// 宣告順序即工具頁的顯示順序。
enum ToolKind {
  lyrics(Icons.lyrics_outlined, Color(0xFF8B5CF6)),
  /// 「編輯歌詞」的圖示也是播放頁選單編輯歌詞項目的唯一來源。
  lyricsEdit(Icons.edit_outlined, Color(0xFFF59E0B)),
  cover(Icons.image_outlined, Color(0xFFEC4899));

  const ToolKind(this.icon, this.accent);

  final IconData icon;

  /// 工具頁卡片 icon 的主色,每個工具一色以便辨識。
  final Color accent;

  String label(AppLocalizations l10n) => switch (this) {
    lyrics => l10n.tools_lyrics,
    lyricsEdit => l10n.lyrics_edit,
    cover => l10n.cover_edit,
  };

  String description(AppLocalizations l10n) => switch (this) {
    lyrics => l10n.tools_lyrics_desc,
    lyricsEdit => l10n.tools_lyrics_edit_desc,
    cover => l10n.tools_cover_desc,
  };

  static ToolKind? fromName(String? name) {
    for (final tool in values) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
