import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/widgets/adjustment_bottom_sheet.dart';
import 'package:seek_player/features/player/widgets/preset_chips.dart';

/// 預設播放速度;重置時回到此值。
const double _kDefaultSpeed = 1.0;

/// 速度面板上方的常用速度快選;皆落在滑桿 0.1 刻度上,與滑桿位置一致。
const List<double> _kSpeedPresets = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0];

String _speedLabel(double speed) => '${speed.toStringAsFixed(1)}x';

/// 快選 chip 用的精簡標籤:整數倍率省略小數(1x、2x),讓整排塞得進一列。
String _presetLabel(double speed) =>
    speed == speed.roundToDouble() ? '${speed.round()}x' : _speedLabel(speed);

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

/// 速度調整面板:上方為常用速度快選,下方滑桿 0.5x ~ 4.0x、間隔 0.1,
/// 調整時即時套用;重置回 1.0x。
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
                PresetChips<double>(
                  values: _kSpeedPresets,
                  labelOf: _presetLabel,
                  // 速度已四捨五入到 0.1,用半格容差比較避免浮點誤差。
                  isSelected: (v) => (speed - v).abs() < 0.05,
                  onSelected: audio.setSpeed,
                ),
                const SizedBox(height: 8),
                Text(
                  _speedLabel(speed),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Slider(
                  min: 0.5,
                  max: 4.0,
                  divisions: 35,
                  value: speed,
                  label: _speedLabel(speed),
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
