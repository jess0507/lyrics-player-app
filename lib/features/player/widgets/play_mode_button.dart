import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 整合播放模式的單一 icon button:順序播放、清單循環、單曲循環、隨機播放
/// 四態,點擊依 [PlayMode.next] 依序循環切換。
class PlayModeButton extends StatelessWidget {
  const PlayModeButton({
    super.key,
    required this.audio,
    required this.enabled,
    this.iconSize = 20.0,
  });

  final AudioPlayerService audio;
  final bool enabled;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<PlayMode>(
      stream: audio.playModeStream,
      builder: (context, snapshot) {
        final mode = snapshot.data ?? PlayMode.repeatAll;
        return IconButton(
          iconSize: iconSize,
          isSelected: mode != PlayMode.sequential,
          tooltip: playModeLabel(l10n, mode),
          onPressed: enabled ? () => audio.setPlayMode(mode.next) : null,
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(playModeIcon(mode)),
              // 順序播放疊一條斜線,與清單循環共用的 repeat 圖示做出區隔。
              if (mode == PlayMode.sequential) const _DiagonalSlash(),
            ],
          ),
        );
      },
    );
  }
}

/// 播放模式對應的基礎圖示;[PlayModeButton] 會在「順序播放」上疊加斜線,
/// 選單等只靠選取狀態(顏色)區分的場景可直接使用此圖示,不需疊線。
IconData playModeIcon(PlayMode mode) => switch (mode) {
  PlayMode.sequential => Icons.repeat,
  PlayMode.repeatAll => Icons.repeat,
  PlayMode.repeatOne => Icons.repeat_one,
  PlayMode.shuffle => Icons.shuffle,
};

/// 播放模式對應的顯示文字。
String playModeLabel(AppLocalizations l10n, PlayMode mode) => switch (mode) {
  PlayMode.sequential => l10n.player_mode_sequential,
  PlayMode.repeatAll => l10n.player_loop,
  PlayMode.repeatOne => l10n.player_mode_repeat_one,
  PlayMode.shuffle => l10n.player_shuffle,
};

/// 疊在 repeat icon 上的斜線，顏色跟隨所在 [IconButton] 當下實際套用的 [IconTheme]。
///
/// 用 [Builder] 取得自身在 element tree 中的 context，
/// 才能讀到 [IconButton] 內部 `IconTheme.merge` 後的顏色，
/// 而不是外層 [StreamBuilder] 尚未套用該樣式前的 context。
class _DiagonalSlash extends StatelessWidget {
  const _DiagonalSlash();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final size = IconTheme.of(context).size ?? 20.0;
        return IgnorePointer(
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: size * 1.15,
              height: 1.4,
              color: IconTheme.of(context).color,
            ),
          ),
        );
      },
    );
  }
}
