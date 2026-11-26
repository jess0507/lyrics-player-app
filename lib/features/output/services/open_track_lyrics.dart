import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/features/player/providers/player_page_controller.dart';
import 'package:seek_player/shared/models/player_default_tab.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

/// 以 [tracks] 為佇列播放第 [index] 首,並開啟播放頁顯示滿版歌詞。
/// 點的就是目前曲目時不重新載入,只開播放頁。
Future<void> openTrackFullScreenLyrics(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks,
  int index,
) async {
  final tag = ref
      .read(audioPlayerServiceProvider)
      .player
      .sequenceState
      ?.currentSource
      ?.tag;
  final currentId = tag is MediaItem ? tag.id : null;
  if (currentId != tracks[index].trackId) {
    final ok = await ref
        .read(playbackControllerProvider)
        .playTracksAt(tracks, index);
    if (!ok) return;
  }
  ref
      .read(settingsControllerProvider.notifier)
      .setPlayerDefaultTab(PlayerDefaultTab.fullScreenLyrics);
  if (!context.mounted) return;
  await ref.read(playerPageControllerProvider.notifier).open(context);
}
