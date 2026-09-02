import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/cover/providers/track_cover_provider.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/player/widgets/cover_actions.dart';
import 'package:seek_player/features/player/widgets/seek_step_slider.dart';
import 'package:seek_player/features/player/widgets/speed_button.dart';
import 'package:seek_player/features/playlists/widgets/add_to_playlist_sheet.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 次控制列「更多」選單中,播放器層級(非歌詞)的動作項目。
enum _PlayerMenuAction {
  speed,

  seekStep,

  addToPlaylist,

  setCover,

  removeCover;

  IconData get icon => switch (this) {
    speed => Icons.speed,
    seekStep => Icons.fast_forward,
    addToPlaylist => Icons.playlist_add,
    setCover => Icons.add_photo_alternate_outlined,
    removeCover => Icons.delete_outline,
  };

  String label(AppLocalizations l10n, {bool hasCover = false}) =>
      switch (this) {
        speed => l10n.player_speed,
        seekStep => l10n.player_seek_step,
        addToPlaylist => l10n.playlist_add_to,
        setCover => hasCover ? l10n.cover_change : l10n.cover_add,
        removeCover => l10n.cover_remove,
      };

  /// 依目前曲目狀態決定是否顯示此項目。
  bool isVisible({
    required Track? track,
    required String? trackId,
    required bool hasCover,
  }) => switch (this) {
    speed || seekStep => true,
    addToPlaylist => track != null,
    setCover => trackId != null,
    removeCover => hasCover,
  };

  /// 執行此項目的動作。呼叫端應傳入選單外(控制列)的 [context]/[ref],
  /// 因為後續面板 / 對話框會在選單關閉後才開啟。
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
      case addToPlaylist:
        if (track != null) showAddToPlaylistSheet(context, ref, track);
      case setCover:
        if (trackId != null) setTrackCover(context, ref, trackId);
      case removeCover:
        if (trackId != null) removeTrackCover(context, ref, trackId);
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

    // 是否已有手動上傳的自訂封面:決定「新增 / 更換」文案與「移除」是否顯示。
    final hasCover =
        id != null && ref.watch(trackCoverProvider(id)).valueOrNull != null;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in _PlayerMenuAction.values)
            if (action.isVisible(track: track, trackId: id, hasCover: hasCover))
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label(l10n, hasCover: hasCover)),
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
