import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

/// 「編輯播放清單」清單:列出已加入播放清單的曲目([addedTracks]),
/// 項目左側為刪除(移出清單)按鈕,右側為拖曳排序圖示。
///
/// [reorderable] 為 false 時(清單經篩選 / 搜尋 / 非清單順序排序,
/// 顯示順序不等於清單順序)拖曳圖示變灰停用,只能刪除。
class PlaylistEditTracksList extends ConsumerWidget {
  const PlaylistEditTracksList({
    super.key,
    required this.playlistId,
    required this.addedTracks,
    required this.audio,
    required this.onRemove,
    this.reorderable = true,
  });

  final int playlistId;
  final List<Track> addedTracks;
  final AudioPlayerService audio;
  final void Function(String trackId) onRemove;

  /// 為 true 時 [addedTracks] 必須是完整且依清單順序的曲目,
  /// 拖曳結果直接寫回清單順序。
  final bool reorderable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: addedTracks.length,
      itemBuilder: (context, index) {
        final track = addedTracks[index];
        const handle = Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.drag_handle),
        );
        return Row(
          key: ValueKey(track.id),
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: scheme.error),
              onPressed: () => onRemove(track.id),
            ),
            Expanded(
              child: TrackListTile(
                track: track,
                audio: audio,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            reorderable
                ? ReorderableDragStartListener(index: index, child: handle)
                : IconTheme.merge(
                    data: IconThemeData(
                      color: scheme.onSurface.withValues(alpha: 0.38),
                    ),
                    child: handle,
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
