import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../l10n/app_localizations.dart';
import 'lyrics_actions_sheet.dart';
import 'secondary_controls_menu.dart';

/// 次控制列圖示的固定大小。
const _kIconSize = 20.0;

/// 次控制列：歌詞、隨機、循環,其餘動作(加入播放清單、播放速度、自動對時、
/// 字體大小、重新匯入、刪除歌詞)收進「更多」選單。
class SecondaryControls extends ConsumerWidget {
  const SecondaryControls({
    super.key,
    required this.audio,
    required this.enabled,
    this.trackId,
    this.title,
  });

  final AudioPlayerService audio;
  final bool enabled;

  /// 目前曲目 id；無曲目時為 null，不顯示自動對時。
  final String? trackId;

  /// 目前曲名，傳給對齊服務。
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = _buildLyrics(context, ref);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StreamBuilder<bool>(
            stream: audio.shuffleModeEnabledStream,
            builder: (context, snapshot) {
              final shuffle = snapshot.data ?? false;
              return IconButton(
                iconSize: _kIconSize,
                isSelected: shuffle,
                onPressed: enabled ? () => audio.setShuffle(!shuffle) : null,
                icon: const Icon(Icons.shuffle),
              );
            },
          ),
          StreamBuilder<LoopMode>(
            stream: audio.loopModeStream,
            builder: (context, snapshot) {
              final mode = snapshot.data ?? LoopMode.off;
              // 三種狀態以「顏色 + 圖示」區分:關閉(灰、repeat)、
              // 全部循環(primary、repeat)、單曲循環(primary、repeat_one)。
              final selected = mode != LoopMode.off;
              final icon = mode == LoopMode.one
                  ? Icons.repeat_one
                  : Icons.repeat;
              return IconButton(
                iconSize: _kIconSize,
                isSelected: selected,
                onPressed: enabled ? () => _cycleLoop(mode) : null,
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon),
                    // 關閉狀態疊一條斜線，與 repeat/repeat_one 共用的圖示做出區隔。
                    if (mode == LoopMode.off) const _DiagonalSlash(),
                  ],
                ),
              );
            },
          ),
          ?lyrics,
          IconButton(
            iconSize: _kIconSize,
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onPressed: enabled
                ? () => showSecondaryControlsMenuSheet(
                    context,
                    ref,
                    audio: audio,
                    trackId: trackId,
                    title: title,
                  )
                : null,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }

  /// 歌詞按鈕:有曲目時提供。點擊彈出歌詞動作表單([lyricsMenuActions]),
  /// 依目前歌詞狀態提供自動產生 / 自動對時 / 字體大小 / 重新匯入 / 刪除。
  Widget? _buildLyrics(BuildContext context, WidgetRef ref) {
    final id = trackId;
    if (id == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      iconSize: _kIconSize,
      tooltip: l10n.lyrics_show,
      onPressed: enabled
          ? () => showLyricsActionsSheet(
              context,
              ref,
              trackId: id,
              title: title ?? '',
            )
          : null,
      icon: const Icon(Icons.lyrics_outlined),
    );
  }

  void _cycleLoop(LoopMode current) {
    final next = switch (current) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    audio.setLoopMode(next);
  }
}

/// 疊在 loop icon 上的斜線，顏色跟隨所在 [IconButton] 當下實際套用的 [IconTheme]。
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
        final size = IconTheme.of(context).size ?? _kIconSize;
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
