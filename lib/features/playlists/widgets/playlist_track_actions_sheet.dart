import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/widgets/track_info_dialog.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/add_to_playlist_sheet.dart';

/// 播放清單內某曲目的操作底部表單:加入其他播放清單、檢視曲目資訊、從本清單移除。
/// [playlistId] 為 null 時(例如「最近播放」等系統清單)不顯示移除選項。
Future<void> showPlaylistTrackActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  int? playlistId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: _PlaylistTrackActionsSheet(playlistId: playlistId, track: track),
    ),
  );
}

class _PlaylistTrackActionsSheet extends ConsumerWidget {
  const _PlaylistTrackActionsSheet({this.playlistId, required this.track});

  final int? playlistId;
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (playlistId case final playlistId?)
          ListTile(
            leading: Icon(Icons.remove_circle_outline, color: scheme.error),
            title: Text(
              l10n.playlist_remove_track,
              style: TextStyle(color: scheme.error),
            ),
            onTap: () {
              Navigator.of(context).pop();
              ref
                  .read(playlistRepositoryProvider)
                  .removeTrack(playlistId, track.id);
            },
          ),
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
