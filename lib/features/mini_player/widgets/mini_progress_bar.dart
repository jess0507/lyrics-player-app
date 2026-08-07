import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';

/// Mini player 頂端的細進度條，反映目前播放位置。
class MiniProgressBar extends StatelessWidget {
  const MiniProgressBar({super.key, required this.audio});

  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<PositionData>(
      stream: audio.positionDataStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final duration = data?.duration ?? Duration.zero;
        final position = data?.position ?? Duration.zero;
        final value = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0;
        return LinearProgressIndicator(
          value: value,
          minHeight: 2,
          backgroundColor: scheme.surfaceContainerHighest,
          color: scheme.primary,
        );
      },
    );
  }
}
