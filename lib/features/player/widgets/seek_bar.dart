import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/shared/format.dart';

/// 播放進度條：顯示目前位置 / 總長度，可拖曳跳轉。
class SeekBar extends StatelessWidget {
  const SeekBar({super.key, required this.audio, required this.enabled});

  final AudioPlayerService audio;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<PositionData>(
        stream: audio.positionDataStream,
        builder: (context, snapshot) {
          final data =
              snapshot.data ??
              const PositionData(Duration.zero, Duration.zero, Duration.zero);
          final total = data.duration.inMilliseconds.toDouble();
          final value = data.position.inMilliseconds
              .clamp(0, total == 0 ? 0 : total.toInt())
              .toDouble();
          return Row(
            children: [
              Text(
                formatDuration(data.position),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: total <= 0 ? 1 : total,
                  value: total <= 0 ? 0 : value,
                  onChanged: enabled && total > 0
                      ? (v) => audio.seek(Duration(milliseconds: v.round()))
                      : null,
                ),
              ),
              Text(
                formatDuration(data.duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
