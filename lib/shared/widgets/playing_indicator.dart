import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';

/// 等化器風格的動態播放指示器:數根長條上下跳動,代表「正在播放」。
///
/// [playing] 為 false 時(暫停)停在靜止狀態並維持低高度,避免畫面持續耗電。
class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({
    super.key,
    required this.color,
    this.playing = true,
    this.size = 16,
    this.barCount = 3,
  });

  final Color color;
  final bool playing;
  final double size;
  final int barCount;

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // 每根長條的相位差,讓跳動錯落有致。
  late final List<double> _phases = List.generate(
    widget.barCount,
    (i) => i / widget.barCount,
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.size / (widget.barCount * 2 - 1);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.barCount; i++)
                _buildBar(barWidth, _heightFactor(i)),
            ],
          );
        },
      ),
    );
  }

  double _heightFactor(int index) {
    if (!widget.playing) return 0.35;
    // 以 sin 波製造上下跳動,夾在 0.25 ~ 1.0 之間。
    final t = (_controller.value + _phases[index]) % 1.0;
    final wave = (0.5 - (t - 0.5).abs()) * 2; // 三角波 0~1
    return 0.25 + wave * 0.75;
  }

  Widget _buildBar(double width, double heightFactor) {
    return Container(
      width: width,
      height: widget.size * heightFactor,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}

/// 清單中目前播放曲目前方的 leading:包好固定寬度與置中,
/// 並依播放 / 暫停狀態決定指示器是否跳動。供各曲目清單共用。
class PlayingTrackLeading extends StatelessWidget {
  const PlayingTrackLeading({
    super.key,
    required this.audio,
    required this.color,
  });

  final AudioPlayerService audio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: audio.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return SizedBox(
          width: 24,
          child: Center(
            child: PlayingIndicator(color: color, playing: playing),
          ),
        );
      },
    );
  }
}
