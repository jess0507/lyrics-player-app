import 'package:flutter/material.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「Output」分頁列出的集合。[name] 同時作為路由片段
/// (`/output/tasks`、`/output/lyrics`);宣告順序即顯示順序。
enum OutputCollection {
  tasks(Icons.pending_actions_outlined),
  lyrics(Icons.lyrics_outlined);

  const OutputCollection(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    tasks => l10n.output_tasks,
    lyrics => l10n.output_lyrics,
  };
}
