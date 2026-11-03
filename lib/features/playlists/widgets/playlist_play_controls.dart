import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 播放清單詳細頁操作列右側:隨機開關與圓形播放全部按鈕。
///
/// 隨機鈕直接切換全域播放模式(開:隨機;關:清單循環),開啟時以主色顯示;
/// 播放鈕以 [tracks] 為佇列播放,隨機開啟時從隨機一首開始。
class PlaylistPlayControls extends ConsumerWidget {
  const PlaylistPlayControls({super.key, required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final audio = ref.watch(audioPlayerServiceProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<PlayMode>(
          stream: audio.playModeStream,
          initialData: audio.playMode,
          builder: (context, snapshot) {
            final shuffling = snapshot.data == PlayMode.shuffle;
            return IconButton(
              tooltip: l10n.player_shuffle,
              isSelected: shuffling,
              color: colorScheme.onSurfaceVariant,
              selectedIcon: Icon(Icons.shuffle, color: colorScheme.primary),
              icon: const Icon(Icons.shuffle),
              onPressed: () => audio.setPlayMode(
                shuffling ? PlayMode.repeatAll : PlayMode.shuffle,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: l10n.playlist_play_all,
          iconSize: 32,
          style: IconButton.styleFrom(minimumSize: const Size.square(52)),
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: tracks.isEmpty
              ? null
              : () {
                  final start = audio.playMode == PlayMode.shuffle
                      ? math.Random().nextInt(tracks.length)
                      : 0;
                  ref.read(playbackControllerProvider).playTracksAt(
                    tracks,
                    start,
                  );
                },
        ),
      ],
    );
  }
}
