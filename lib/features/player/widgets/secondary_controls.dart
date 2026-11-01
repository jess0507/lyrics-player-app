import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/player/services/open_tool_editor.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/widgets/play_mode_button.dart';
import 'package:seek_player/features/player/widgets/secondary_controls_menu.dart';
import 'package:seek_player/features/player/widgets/share_track_button.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';

/// 次控制列圖示的固定大小。
const _kIconSize = 20.0;

/// 次控制列:播放模式、分享、歌詞(進歌詞編輯頁),其餘動作(播放速度、
/// 快轉間隔、歌詞字體大小、歌詞對齊方式、加入播放清單、編輯封面)收進「更多」選單。
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
    final lyrics = _buildLyrics(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PlayModeButton(audio: audio, enabled: enabled, iconSize: _kIconSize),
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

  /// 歌詞按鈕:有曲目時提供。點擊關閉播放頁並進「工具 › 製作歌詞」的
  /// 該曲編輯頁([LyricsEditorPage])。
  Widget? _buildLyrics(BuildContext context) {
    final id = trackId;
    if (id == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      iconSize: _kIconSize,
      tooltip: l10n.lyrics_show,
      onPressed: enabled
          ? () => openToolEditorFromPlayer(
              context,
              tool: ToolKind.lyrics,
              trackId: id,
            )
          : null,
      icon: const Icon(Icons.lyrics_outlined),
    );
  }
}
