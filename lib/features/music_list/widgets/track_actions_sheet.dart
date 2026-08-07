import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/playlists/widgets/add_to_playlist_sheet.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/widgets/track_info_dialog.dart';

/// 顯示曲目操作底部表單:檢視曲目資訊、加入播放清單。
Future<void> showTrackActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) =>
        SafeArea(child: _TrackActionsSheet(track: track)),
  );
}

class _TrackActionsSheet extends ConsumerWidget {
  const _TrackActionsSheet({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.playlist_add),
          title: Text(l10n.playlist_add_to),
          onTap: () {
            Navigator.of(context).pop();
            showAddToPlaylistSheet(context, ref, track);
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.music_track_info),
          onTap: () {
            Navigator.of(context).pop();
            showTrackInfoDialog(context, track);
          },
        ),
      ],
    );
  }
}
