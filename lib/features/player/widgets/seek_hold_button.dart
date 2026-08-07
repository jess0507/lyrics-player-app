import 'dart:async';

import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';

/// 快進 / 快退按鈕：點擊一下步進 [delta]，持續長按時每 300ms 連續步進。
class SeekHoldButton extends StatefulWidget {
  const SeekHoldButton({
    super.key,
    required this.audio,
    required this.enabled,
    required this.delta,
    required this.icon,
    required this.tooltip,
  });

  final AudioPlayerService audio;
  final bool enabled;
  final Duration delta;
  final IconData icon;
  final String tooltip;

  @override
  State<SeekHoldButton> createState() => _SeekHoldButtonState();
}

class _SeekHoldButtonState extends State<SeekHoldButton> {
  Timer? _timer;

  void _startRepeat() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => widget.audio.seekRelative(widget.delta),
    );
  }

  void _stopRepeat() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.enabled ? _startRepeat : null,
      onLongPressUp: _stopRepeat,
      child: IconButton(
        iconSize: 30,
        tooltip: widget.tooltip,
        onPressed: widget.enabled
            ? () => widget.audio.seekRelative(widget.delta)
            : null,
        icon: Icon(widget.icon),
      ),
    );
  }
}
