import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

/// 「編輯播放清單」清單:只列出已加入播放清單的曲目([addedTracks],依既有
/// 順序排列),項目最前面有拖曳排序圖示,或點刪除圖示移出清單。
class PlaylistEditTracksList extends ConsumerWidget {
  const PlaylistEditTracksList({
    super.key,
    required this.playlistId,
    required this.addedTracks,
    required this.audio,
    required this.onRemove,
  });

  final int playlistId;
  final List<Track> addedTracks;
  final AudioPlayerService audio;
  final void Function(String trackId) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: addedTracks.length,
      itemBuilder: (context, index) {
        final track = addedTracks[index];
        return Row(
          key: ValueKey(track.id),
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.drag_handle),
              ),
            ),
            Expanded(
              child: TrackListTile(
                track: track,
                audio: audio,
                contentPadding: EdgeInsets.zero,
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => onRemove(track.id),
                ),
                onTap: () => onRemove(track.id),
              ),
            ),
          ],
        );
      },
      onReorderItem: (oldIndex, newIndex) {
        final ids = addedTracks.map((t) => t.id).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        ref.read(playlistRepositoryProvider).setTrackIds(playlistId, ids);
      },
    );
  }
}
