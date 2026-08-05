import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../l10n/app_localizations.dart';
import 'lyrics_actions_sheet.dart';
import 'play_mode_button.dart';
import 'secondary_controls_menu.dart';
import 'share_track_button.dart';

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
          PlayModeButton(
            audio: audio,
            enabled: enabled,
            iconSize: _kIconSize,
          ),
          ShareTrackButton(
            enabled: enabled,
            trackId: trackId,
            iconSize: _kIconSize,
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

}
