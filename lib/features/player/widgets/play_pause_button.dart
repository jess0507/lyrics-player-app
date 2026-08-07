import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';

/// 播放 / 暫停按鈕，載入來源時顯示轉圈進度。
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.audio,
    required this.enabled,
  });

  final AudioPlayerService audio;
  final bool enabled;

  /// 固定外框尺寸，避免載入轉圈與按鈕切換時大小跳動。
  static const _kSize = 64.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _kSize,
      child: StreamBuilder<PlayerState>(
        stream: audio.playerStateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final processing = state?.processingState;
          final playing = state?.playing ?? false;

          // 只在 loading(載入來源)顯示 spinner;buffering 多半是 seek 後的
          // 瞬間狀態,換成 spinner 會讓按鈕閃爍跳動。
          if (processing == ProcessingState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: IconButton.filled(
              iconSize: 40,
              onPressed: !enabled ? null : (playing ? audio.pause : audio.play),
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          );
        },
      ),
    );
  }
}
