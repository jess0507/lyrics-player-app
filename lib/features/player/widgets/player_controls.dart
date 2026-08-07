import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/widgets/play_pause_button.dart';
import 'package:seek_player/features/player/widgets/seek_hold_button.dart';

/// 快進 / 快退的單次步進量。
const _kSeekStep = Duration(seconds: 5);

/// 播放控制區：主控制列（切歌、快進退、播放）與次控制列（隨機、速度、循環）。
class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key, required this.audio, required this.enabled});

  final AudioPlayerService audio;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // 主控制列：上一首、快退、播放/暫停、快進、下一首。
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SeekHoldButton(
              audio: audio,
              enabled: enabled,
              delta: -_kSeekStep,
              icon: Icons.replay_5,
              tooltip: l10n.player_rewind,
            ),
            IconButton(
              iconSize: 30,
              onPressed: enabled ? audio.seekToPrevious : null,
              icon: const Icon(Icons.skip_previous),
            ),
            PlayPauseButton(audio: audio, enabled: enabled),
            IconButton(
              iconSize: 30,
              onPressed: enabled ? audio.seekToNext : null,
              icon: const Icon(Icons.skip_next),
            ),
            SeekHoldButton(
              audio: audio,
              enabled: enabled,
              delta: _kSeekStep,
              icon: Icons.forward_5,
              tooltip: l10n.player_forward,
            ),
          ],
        ),
      ],
    );
  }
}
