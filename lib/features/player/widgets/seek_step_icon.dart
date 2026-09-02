import 'package:flutter/material.dart';

/// 快進 / 快退按鈕圖示:一律以環狀箭頭疊上秒數文字呈現,
/// 不依秒數切換 Material 內建的數字圖示,任何步進秒數外觀都一致。
class SeekStepIcon extends StatelessWidget {
  const SeekStepIcon({
    super.key,
    required this.seconds,
    required this.forward,
    this.size,
    this.color,
  });

  /// 步進秒數。
  final int seconds;

  /// true 為快進(順時針箭頭),false 為快退(逆時針箭頭)。
  final bool forward;

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? IconTheme.of(context).size ?? 24;
    final iconColor = color ?? IconTheme.of(context).color;
    // Icons.replay 是逆時針箭頭;水平翻轉即為順時針的快進箭頭。
    return SizedBox.square(
      dimension: iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.flip(
            flipX: forward,
            child: Icon(Icons.replay, size: iconSize, color: iconColor),
          ),
          Positioned(
            // 數字靠下對齊環狀箭頭的開口,位置比照內建數字圖示。
            top: iconSize * 0.36,
            child: Text(
              '$seconds',
              style: TextStyle(
                fontSize: iconSize * 0.34,
                fontWeight: FontWeight.w700,
                height: 1,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
