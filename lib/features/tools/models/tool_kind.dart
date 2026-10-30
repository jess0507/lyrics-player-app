import 'package:flutter/material.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具分頁提供的工具:先選工具、再選曲目,最後開啟該工具的動作表單。
///
/// [name] 同時作為選曲頁的路由片段(`/tools/lyrics`、`/tools/cover`)。
enum ToolKind {
  lyrics(Icons.lyrics_outlined),
  cover(Icons.image_outlined);

  const ToolKind(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    lyrics => l10n.tools_lyrics,
    cover => l10n.cover_edit,
  };

  String description(AppLocalizations l10n) => switch (this) {
    lyrics => l10n.tools_lyrics_desc,
    cover => l10n.tools_cover_desc,
  };

  static ToolKind? fromName(String? name) {
    for (final tool in values) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
