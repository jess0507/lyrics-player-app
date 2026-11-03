import 'package:flutter/material.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 「增加項目」清單:點擊「+」加入、已加入顯示打勾可再點一次移除;
/// 清單內容由呼叫端決定(進頁快照再經篩選 / 搜尋 / 排序),
/// 只有圖示狀態隨 [addedIds] 即時更新。
class PlaylistAddTracksList extends StatelessWidget {
  const PlaylistAddTracksList({
    super.key,
    required this.tracks,
    required this.addedIds,
    required this.audio,
    required this.onToggle,
  });

  final List<Track> tracks;
  final Set<String> addedIds;
  final AudioPlayerService audio;

  /// [added] 為點擊當下是否已加入。
  final void Function(String trackId, bool added) onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final added = addedIds.contains(track.id);
        return TrackListTile(
          key: ValueKey(track.id),
          track: track,
          audio: audio,
          contentPadding: const EdgeInsets.only(left: 16.0),
          trailing: IconButton(
            icon: added
                ? Icon(Icons.check, color: scheme.primary)
                : const Icon(Icons.add),
            onPressed: () => onToggle(track.id, added),
          ),
          onTap: () => onToggle(track.id, added),
        );
      },
    );
  }
}
