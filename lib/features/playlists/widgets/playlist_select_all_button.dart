import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「增加項目」頁排序右側的全選鈕:對象為目前篩選 / 搜尋出的 [tracks]。
/// 全部已加入時改為取消全選(移除這些曲目),否則加入尚未加入者。
class PlaylistSelectAllButton extends ConsumerWidget {
  const PlaylistSelectAllButton({
    super.key,
    required this.playlistId,
    required this.tracks,
    required this.addedIds,
    required this.analyticsSource,
  });

  final int playlistId;
  final List<Track> tracks;
  final Set<String> addedIds;
  final AnalyticsSource analyticsSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final allAdded =
        tracks.isNotEmpty && tracks.every((t) => addedIds.contains(t.trackId));
    return IconButton(
      tooltip: allAdded ? l10n.playlist_deselect_all : l10n.playlist_select_all,
      icon: Icon(allAdded ? Icons.deselect : Icons.select_all),
      onPressed: tracks.isEmpty
          ? null
          : () {
              final repo = ref.read(playlistRepositoryProvider);
              logAnalyticsAction(
                allAdded
                    ? PlaylistAction.deselectAllTracks
                    : PlaylistAction.selectAllTracks,
                source: analyticsSource,
              );
              if (allAdded) {
                repo.removeTracks(playlistId, {
                  for (final t in tracks) t.trackId,
                });
              } else {
                repo.addTracks(playlistId, [
                  for (final t in tracks)
                    if (!addedIds.contains(t.trackId)) t.trackId,
                ]);
              }
            },
    );
  }
}
