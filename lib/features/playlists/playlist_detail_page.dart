import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/features/playlists/models/playlist_display_name.dart';
import 'package:seek_player/features/playlists/playlist_add_tracks_page.dart';
import 'package:seek_player/features/playlists/providers/playlist_tracks_provider.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/providers/recently_played_provider.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/playlist_track_actions_sheet.dart';
import 'package:seek_player/features/playlists/widgets/recently_played_track_list.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 單一播放清單內容:播放全部、逐首播放、移除、拖曳排序。
class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  Future<void> _clearRecentlyPlayed(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlist_clear_recently_played),
        content: Text(l10n.playlist_clear_recently_played_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(playlistRepositoryProvider).clearRecentlyPlayed();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    final title = playlist == null
        ? l10n.tab_playlists
        : playlistDisplayName(playlist, l10n);

    // 「最近播放」是系統清單:不可增加項目 / 排序 / 逐首移除,只能整份清除。
    if (playlist?.isRecentlyPlayed ?? false) {
      final recentlyPlayed = ref.watch(recentlyPlayedProvider);
      return Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (recentlyPlayed.isNotEmpty)
              IconButton(
                tooltip: l10n.playlist_clear_recently_played,
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _clearRecentlyPlayed(context, ref),
              ),
          ],
        ),
        body: const RecentlyPlayedTrackList(),
      );
    }

    final tracks = ref.watch(playlistTracksProvider(playlistId));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (tracks.isNotEmpty)
            IconButton(
              tooltip: l10n.playlist_play_all,
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () =>
                  ref.read(playbackControllerProvider).playTracksAt(tracks, 0),
            ),
        ],
      ),
      body: Column(
        children: [
          // 最上方兩個入口,都往上展開同一張挑選/排序曲目頁:
          // 「增加項目」新增曲目、「編輯播放清單」調整已加入曲目的順序。
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        showPlaylistAddTracksSheet(context, playlistId),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.playlist_add_item),
                  ),
                  // 清單為空時沒有項目可排序或刪除，不顯示編輯按鈕。
                  if (tracks.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => showPlaylistAddTracksSheet(
                        context,
                        playlistId,
                        reorderable: true,
                      ),
                      icon: const Icon(Icons.edit),
                      label: Text(l10n.playlist_edit),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(child: _buildTrackList(context, ref)),
        ],
      ),
    );
  }

  Widget _buildTrackList(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tracks = ref.watch(playlistTracksProvider(playlistId));
    final audio = ref.watch(audioPlayerServiceProvider);

    return tracks.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l10n.playlist_empty, textAlign: TextAlign.center),
            ),
          )
        : StreamBuilder<SequenceState?>(
            stream: audio.player.sequenceStateStream,
            builder: (context, snapshot) {
              final tag = snapshot.data?.currentSource?.tag;
              final currentId = tag is MediaItem ? tag.id : null;
              return ReorderableListView.builder(
                itemCount: tracks.length,
                onReorderItem: (oldIndex, newIndex) {
                  final ids = tracks.map((t) => t.id).toList();
                  final moved = ids.removeAt(oldIndex);
                  ids.insert(newIndex, moved);
                  ref
                      .read(playlistRepositoryProvider)
                      .setTrackIds(playlistId, ids);
                },
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isCurrent = track.id == currentId;
                  return TrackListTile(
                    key: ValueKey(track.id),
                    track: track,
                    audio: audio,
                    isCurrent: isCurrent,
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => showPlaylistTrackActionsSheet(
                        context,
                        ref,
                        track,
                        playlistId: playlistId,
                      ),
                    ),
                    onTap: () => ref
                        .read(playbackControllerProvider)
                        .playTracksAt(tracks, index),
                  );
                },
              );
            },
          );
  }
}
