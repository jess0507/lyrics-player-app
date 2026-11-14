import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/shared/format.dart';

/// Mini player 播放鍵左側的目前播放位置(如 `0:01`)。
class MiniPositionText extends StatelessWidget {
  const MiniPositionText({super.key, required this.audio});

  final AudioPlayerService audio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: audio.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        return Text(
          formatDuration(position),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            // 等寬數字，避免秒數跳動時文字寬度改變造成左右晃動。
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}
