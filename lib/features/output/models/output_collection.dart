import 'package:flutter/material.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';

/// 工具頁「產出」區列出的集合。[name] 同時作為路由片段
/// (`/tools/output/tasks`、`/tools/output/lyrics`);宣告順序即顯示順序。
enum OutputCollection {
  tasks,
  lyrics;

  /// 列表前方的 icon;歌詞沿用底部導覽「播放清單」的 app logo SVG。
  Widget get icon => switch (this) {
    tasks => const Icon(Icons.pending_actions_outlined),
    lyrics => SvgIcon(Assets.icon.appLogoSvg),
  };

  String label(AppLocalizations l10n) => switch (this) {
    tasks => l10n.output_tasks,
    lyrics => l10n.output_lyrics,
  };

  /// 集合沒有曲目時,工具頁列表上顯示的副標。
  String emptyLabel(AppLocalizations l10n) => switch (this) {
    tasks => l10n.output_tasks_empty,
    lyrics => l10n.output_lyrics_empty,
  };
}
