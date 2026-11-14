import 'package:flutter/material.dart';

import 'package:seek_player/l10n/app_localizations.dart';

/// 預覽歌詞時「更多」選單的動作。
enum LyricsEditMoreAction { share, export }

/// 預覽歌詞時 AppBar 的「更多」按鈕:分享或匯出歌詞檔。
/// 回呼帶入按鈕自身的 context,供分享面板在 iPad 上定位。
class LyricsEditMoreButton extends StatelessWidget {
  const LyricsEditMoreButton({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  final void Function(BuildContext buttonContext, LyricsEditMoreAction action)
  onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<LyricsEditMoreAction>(
      enabled: enabled,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => onSelected(context, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: LyricsEditMoreAction.share,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.player_share),
          ),
        ),
        PopupMenuItem(
          value: LyricsEditMoreAction.export,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.lyrics_edit_export),
          ),
        ),
      ],
    );
  }
}
