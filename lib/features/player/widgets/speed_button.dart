import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/widgets/adjustment_bottom_sheet.dart';

/// 預設播放速度;重置時回到此值。
const double _kDefaultSpeed = 1.0;

/// 播放速度按鈕:點擊開啟速度調整面板,非 1.0x 時顯示選取狀態。
class SpeedButton extends StatelessWidget {
  const SpeedButton({
    super.key,
    required this.audio,
    required this.enabled,
    this.iconSize,
    this.iconColor,
  });

  final AudioPlayerService audio;
  final bool enabled;
  final double? iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: audio.speedStream,
      builder: (context, snapshot) {
        final speed = snapshot.data ?? _kDefaultSpeed;
        return IconButton(
          iconSize: iconSize,
          color: iconColor,
          isSelected: speed != _kDefaultSpeed,
          tooltip: '${speed.toStringAsFixed(1)}x',
          onPressed: enabled ? () => showSpeedSheet(context, audio) : null,
          icon: const Icon(Icons.speed),
        );
      },
    );
  }
}

/// 速度調整面板:0.5x ~ 4.0x,間隔 0.1,調整時即時套用;重置回 1.0x。
void showSpeedSheet(BuildContext context, AudioPlayerService audio) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return AdjustmentBottomSheet(
        title: l10n.player_speed,
        onReset: () => audio.setSpeed(_kDefaultSpeed),
        child: StreamBuilder<double>(
          stream: audio.speedStream,
          builder: (context, snapshot) {
            final speed = (snapshot.data ?? _kDefaultSpeed).clamp(0.5, 4.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${speed.toStringAsFixed(1)}x',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Slider(
                  min: 0.5,
                  max: 4.0,
                  divisions: 35,
                  value: speed,
                  label: '${speed.toStringAsFixed(1)}x',
                  onChanged: (v) =>
                      audio.setSpeed(double.parse(v.toStringAsFixed(1))),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
