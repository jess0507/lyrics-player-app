import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/widgets/play_pause_button.dart';
import 'package:seek_player/features/player/widgets/seek_hold_button.dart';
import 'package:seek_player/features/player/widgets/seek_step_icon.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

/// 播放控制區：主控制列（切歌、快進退、播放）與次控制列（隨機、速度、循環）。
/// 快進 / 快退的單次步進秒數來自設定,可在播放速度面板中調整。
class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key, required this.audio, required this.enabled});

  final AudioPlayerService audio;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stepSeconds = ref.watch(
      settingsControllerProvider.select((s) => s.seekStepSeconds),
    );
    final seekStep = Duration(seconds: stepSeconds);
    return Column(
      children: [
        // 主控制列：上一首、快退、播放/暫停、快進、下一首。
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SeekHoldButton(
              audio: audio,
              enabled: enabled,
              delta: -seekStep,
              icon: SeekStepIcon(seconds: stepSeconds, forward: false),
              tooltip: l10n.player_rewind(stepSeconds),
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
              delta: seekStep,
              icon: SeekStepIcon(seconds: stepSeconds, forward: true),
              tooltip: l10n.player_forward(stepSeconds),
            ),
          ],
        ),
      ],
    );
  }
}
