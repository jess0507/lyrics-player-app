import 'package:flutter/material.dart';
import 'package:seek_player/features/playlists/widgets/playlist_action_bar.dart';

/// 播放清單詳細頁內容頂端:靠左的清單名稱,下方為 [PlaylistActionBar]
/// (左側 [actions],最右側 [trailing])。
class PlaylistDetailHeader extends StatelessWidget {
  const PlaylistDetailHeader({
    super.key,
    required this.title,
    required this.actions,
    this.trailing,
  });

  final String title;
  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actions.isNotEmpty || trailing != null)
          PlaylistActionBar(actions: actions, trailing: trailing),
      ],
    );
  }
}
