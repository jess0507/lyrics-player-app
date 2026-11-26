import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/output/services/open_track_lyrics.dart';
import 'package:seek_player/features/playlists/widgets/playlist_track_actions_sheet.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// Output 集合共用的曲目清單:點曲目以整份清單為佇列播放,並開播放頁的
/// 滿版歌詞;長按開曲目操作選單。目前播放中的曲目會強調顯示。
class OutputTrackList extends ConsumerWidget {
  const OutputTrackList({
    super.key,
    required this.tracks,
    required this.source,
    this.trailingBuilder,
  });

  final List<Track> tracks;

  /// GA 來源畫面。
  final AnalyticsSource source;

  /// 每列的 trailing(如任務種類);null 則不顯示。
  final Widget? Function(BuildContext context, int index)? trailingBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioPlayerServiceProvider);
    return StreamBuilder<SequenceState?>(
      stream: audio.player.sequenceStateStream,
      builder: (context, snapshot) {
        final tag = snapshot.data?.currentSource?.tag;
        final currentId = tag is MediaItem ? tag.id : null;
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackListTile(
              key: ValueKey(track.trackId),
              track: track,
              audio: audio,
              isCurrent: track.trackId == currentId,
              trailing: trailingBuilder?.call(context, index),
              onTap: () {
                logAnalyticsAction(PlaylistAction.playTrack, source: source);
                openTrackFullScreenLyrics(context, ref, tracks, index);
              },
              onLongPress: () =>
                  showPlaylistTrackActionsSheet(context, ref, track),
            );
          },
        );
      },
    );
  }
}
