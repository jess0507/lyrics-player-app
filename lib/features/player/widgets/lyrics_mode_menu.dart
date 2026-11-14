import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/models/player_default_tab.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/player/services/open_tool_editor.dart';
import 'package:seek_player/features/player/widgets/lyrics_menu_action.dart';
import 'package:seek_player/features/player/widgets/play_mode_button.dart';
import 'package:seek_player/features/player/widgets/seek_step_slider.dart';
import 'package:seek_player/features/player/widgets/speed_button.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';

/// 預設播放速度,用來判斷是否顯示選取狀態。
const double _kDefaultSpeed = 1.0;

/// 歌詞滿版模式專有的選單動作(播放模式、播放速度、快進退秒數、「顯示封面」
/// 與「製作歌詞」)。歌詞相關動作另以共用的 [LyricsMenuAction] 表示。
enum _LyricsModeAction { hideLyrics, playMode, speed, seekStep, makeLyrics }

/// 歌詞滿版模式下的 AppBar 選單:整合「顯示封面(關閉歌詞)」、次控制列功能
/// (隨機、循環、播放速度、快進退秒數),最下方是歌詞顯示設定(字體大小、
/// 對齊方式,僅在已有歌詞時出現)與「編輯歌詞」「製作歌詞」。
/// 其餘歌詞動作(搜尋、匯入、對時、下載、刪除…)統一由製作歌詞頁提供。
class LyricsModeMenu extends ConsumerWidget {
  const LyricsModeMenu({
    super.key,
    required this.audio,
    required this.trackId,
    required this.title,
  });

  final AudioPlayerService audio;
  final String trackId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lyrics = ref.watch(trackLyricsProvider(trackId)).valueOrNull;
    final hasLyrics = lyrics != null && lyrics.isNotEmpty;
    final seekStepSeconds = ref.watch(
      settingsControllerProvider.select((s) => s.seekStepSeconds),
    );

    return PopupMenuButton<Object>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _LyricsModeAction.hideLyrics,
          child: _MenuRow(icon: Icons.image_outlined, label: l10n.lyrics_hide),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _LyricsModeAction.playMode,
          child: StreamBuilder<PlayMode>(
            stream: audio.playModeStream,
            builder: (context, snapshot) {
              final mode = snapshot.data ?? PlayMode.repeatAll;
              return _MenuRow(
                icon: playModeIcon(mode),
                label: playModeLabel(l10n, mode),
                selected: mode != PlayMode.sequential,
              );
            },
          ),
        ),
        PopupMenuItem(
          value: _LyricsModeAction.speed,
          child: StreamBuilder<double>(
            stream: audio.speedStream,
            builder: (context, snapshot) {
              final speed = snapshot.data ?? _kDefaultSpeed;
              return _MenuRow(
                icon: Icons.speed,
                label: l10n.player_speed,
                trailing: '${speed.toStringAsFixed(1)}x',
                selected: speed != _kDefaultSpeed,
              );
            },
          ),
        ),
        PopupMenuItem(
          value: _LyricsModeAction.seekStep,
          child: _MenuRow(
            icon: Icons.fast_forward,
            label: l10n.player_seek_step,
            trailing: '${seekStepSeconds}s',
            selected: seekStepSeconds != SettingsState.kDefaultSeekStepSeconds,
          ),
        ),
        if (hasLyrics) ...[
          const PopupMenuDivider(),
          for (final action in const [
            LyricsMenuAction.fontSize,
            LyricsMenuAction.textAlign,
          ])
            PopupMenuItem(
              value: action,
              child: _MenuRow(icon: action.icon, label: action.label(l10n)),
            ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: LyricsMenuAction.edit,
          child: _MenuRow(
            icon: LyricsMenuAction.edit.icon,
            label: LyricsMenuAction.edit.label(l10n),
          ),
        ),
        PopupMenuItem(
          value: _LyricsModeAction.makeLyrics,
          child: _MenuRow(icon: ToolKind.lyrics.icon, label: l10n.tools_lyrics),
        ),
      ],
    );
  }

  void _onSelected(BuildContext context, WidgetRef ref, Object value) {
    if (value is LyricsMenuAction) {
      runLyricsMenuAction(context, ref, value, trackId: trackId, title: title);
      return;
    }
    final action = value as _LyricsModeAction;
    logAnalyticsAction(
      PlayerAction.menuSelect,
      source: AnalyticsSource.lyricsMenu,
      option: action,
    );
    switch (action) {
      case _LyricsModeAction.hideLyrics:
        _hideLyrics(ref);
      case _LyricsModeAction.playMode:
        final next = audio.playMode.next;
        logAnalyticsAction(
          PlayerAction.playModeChange,
          source: AnalyticsSource.lyricsMenu,
          option: next,
        );
        audio.setPlayMode(next);
      case _LyricsModeAction.speed:
        showSpeedSheet(context, audio);
      case _LyricsModeAction.seekStep:
        showSeekStepSheet(context);
      case _LyricsModeAction.makeLyrics:
        openToolEditorFromPlayer(
          context,
          tool: ToolKind.lyrics,
          trackId: trackId,
        );
    }
  }

  /// 手動退出滿版 = 把預設分頁設回封面;播放頁依設定退回封面,
  /// 切歌後也不會再自動跳回滿版。
  void _hideLyrics(WidgetRef ref) {
    ref
        .read(settingsControllerProvider.notifier)
        .setPlayerDefaultTab(PlayerDefaultTab.artwork);
  }
}

/// 選單列:圖示 + 文字,選取時上色,可選右側狀態文字(如速度倍率)。
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : null;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(color: color)),
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              trailing!,
              style: TextStyle(color: color ?? scheme.outline),
            ),
          ),
      ],
    );
  }
}
