import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/player/services/open_tool_editor.dart';
import 'package:seek_player/features/player/widgets/lyrics_font_size_sheet.dart';
import 'package:seek_player/features/player/widgets/lyrics_text_align_sheet.dart';
import 'package:seek_player/features/player/widgets/seek_step_slider.dart';
import 'package:seek_player/features/player/widgets/speed_button.dart';
import 'package:seek_player/features/playlists/widgets/add_to_playlist_sheet.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 次控制列「更多」選單中,播放器層級(非歌詞)的動作項目。
enum _PlayerMenuAction {
  speed,

  seekStep,

  addToPlaylist,

  /// 進「工具 › 更改封面」的該曲編輯頁,新增 / 更換 / 移除都在那裡做。
  editCover,

  /// 歌詞字體大小;有曲目時顯示。
  lyricsFontSize,

  /// 歌詞對齊方式(左 / 中 / 右);有曲目時顯示。
  lyricsTextAlign;

  IconData get icon => switch (this) {
    speed => Icons.speed,
    seekStep => Icons.fast_forward,
    lyricsFontSize => Icons.text_fields,
    lyricsTextAlign => Icons.format_align_left,
    addToPlaylist => Icons.playlist_add,
    editCover => Icons.image_outlined,
  };

  String label(AppLocalizations l10n) => switch (this) {
    speed => l10n.player_speed,
    seekStep => l10n.player_seek_step,
    lyricsFontSize => l10n.lyrics_font_size,
    lyricsTextAlign => l10n.lyrics_text_align,
    addToPlaylist => l10n.playlist_add_to,
    editCover => l10n.cover_edit,
  };

  /// 依目前曲目狀態決定是否顯示此項目。
  bool isVisible({required Track? track, required String? trackId}) =>
      switch (this) {
        speed || seekStep => true,
        addToPlaylist => track != null,
        lyricsFontSize || lyricsTextAlign || editCover => trackId != null,
      };

  void run(
    BuildContext context,
    WidgetRef ref, {
    required AudioPlayerService audio,
    Track? track,
    String? trackId,
  }) {
    switch (this) {
      case speed:
        showSpeedSheet(context, audio);
      case seekStep:
        showSeekStepSheet(context);
      case lyricsFontSize:
        showLyricsFontSizeSheet(context);
      case lyricsTextAlign:
        showLyricsTextAlignSheet(context);
      case addToPlaylist:
        if (track != null) showAddToPlaylistSheet(context, ref, track);
      case editCover:
        if (trackId != null) {
          openToolEditorFromPlayer(
            context,
            tool: ToolKind.cover,
            trackId: trackId,
            track: track,
          );
        }
    }
  }
}

void showSecondaryControlsMenuSheet(
  BuildContext context,
  WidgetRef ref, {
  required AudioPlayerService audio,
  String? trackId,
  String? title,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 解除預設最大高度(螢幕 9/16),依內容撐高,項目多時不會 overflow。
    isScrollControlled: true,
    builder: (sheetContext) => _SecondaryControlsMenuSheet(
      parentContext: context,
      parentRef: ref,
      audio: audio,
      trackId: trackId,
      title: title ?? '',
    ),
  );
}

class _SecondaryControlsMenuSheet extends ConsumerWidget {
  const _SecondaryControlsMenuSheet({
    required this.parentContext,
    required this.parentRef,
    required this.audio,
    required this.title,
    this.trackId,
  });

  /// 呼叫端(控制列)的 context 與 ref,用來開啟後續面板,生命週期不隨本表單結束。
  final BuildContext parentContext;
  final WidgetRef parentRef;

  final AudioPlayerService audio;
  final String title;
  final String? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // 只有能在音樂庫對應到曲目時才提供「加入播放清單」。
    final id = trackId;
    final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
    final trackIndex = id == null ? -1 : tracks.indexWhere((t) => t.id == id);
    final track = trackIndex < 0 ? null : tracks[trackIndex];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in _PlayerMenuAction.values)
            if (action.isVisible(track: track, trackId: id))
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label(l10n)),
                // 先關閉選單,再以呼叫端 context/ref 執行對應動作。
                onTap: () {
                  Navigator.of(context).pop();
                  action.run(
                    parentContext,
                    parentRef,
                    audio: audio,
                    track: track,
                    trackId: trackId,
                  );
                },
              ),
        ],
      ),
    );
  }
}
