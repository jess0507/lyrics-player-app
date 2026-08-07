import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/cover/providers/track_cover_provider.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/playlists/widgets/add_to_playlist_sheet.dart';
import 'package:seek_player/features/player/widgets/cover_actions.dart';
import 'package:seek_player/features/player/widgets/lyrics_menu_action.dart';
import 'package:seek_player/features/player/widgets/speed_button.dart';

/// 次控制列「更多」選單中,播放器層級(非歌詞)的動作項目。
/// 歌詞相關動作另以共用的 [LyricsMenuAction] 表示。
enum _PlayerMenuAction {
  /// 加入播放清單;能在音樂庫對應到曲目時顯示。
  addToPlaylist,

  /// 新增 / 更換自訂封面;有曲目時顯示,文案依是否已有自訂封面切換。
  setCover,

  /// 移除自訂封面;僅在已有自訂封面時顯示(內嵌封面移不掉,不算在內)。
  removeCover,

  /// 播放速度;一律顯示。
  speed;

  IconData get icon => switch (this) {
    addToPlaylist => Icons.playlist_add,
    setCover => Icons.add_photo_alternate_outlined,
    removeCover => Icons.delete_outline,
    speed => Icons.speed,
  };

  String label(AppLocalizations l10n, {bool hasCover = false}) =>
      switch (this) {
        addToPlaylist => l10n.playlist_add_to,
        setCover => hasCover ? l10n.cover_change : l10n.cover_add,
        removeCover => l10n.cover_remove,
        speed => l10n.player_speed,
      };
}

/// 次控制列「更多」選單:把較不常用的動作(加入播放清單、播放速度、歌詞操作)
/// 收進此底部表單,讓控制列只保留高頻操作。對應 [LyricsModeMenu] 的選單,但不含
/// 「顯示封面(關閉歌詞)」—— 該動作只屬於歌詞滿版模式。
///
/// 後續動作(各面板 / 對話框)以呼叫端的 [context]/[ref] 開啟,
/// 避免本表單關閉後沿用已失效的 context。
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
          if (track != null)
            _playerTile(context, _PlayerMenuAction.addToPlaylist, l10n, track),
          if (id != null)
            _playerTile(context, _PlayerMenuAction.setCover, l10n, null,
                hasCover),
          if (hasCover)
            _playerTile(context, _PlayerMenuAction.removeCover, l10n),
          _playerTile(context, _PlayerMenuAction.speed, l10n),
        ],
      ),
    );
  }

  Widget _playerTile(
    BuildContext sheetContext,
    _PlayerMenuAction action,
    AppLocalizations l10n, [
    Track? track,
    bool hasCover = false,
  ]) {
    return ListTile(
      leading: Icon(action.icon),
      title: Text(action.label(l10n, hasCover: hasCover)),
      onTap: () => _selectPlayer(sheetContext, action, track),
    );
  }

  /// 先關閉選單,再以呼叫端 context/ref 執行對應動作。
  void _selectPlayer(
    BuildContext sheetContext,
    _PlayerMenuAction action,
    Track? track,
  ) {
    Navigator.of(sheetContext).pop();
    final id = trackId;
    switch (action) {
      case _PlayerMenuAction.addToPlaylist:
        if (track != null) {
          showAddToPlaylistSheet(parentContext, parentRef, track);
        }
      case _PlayerMenuAction.setCover:
        if (id != null) setTrackCover(parentContext, parentRef, id);
      case _PlayerMenuAction.removeCover:
        if (id != null) removeTrackCover(parentContext, parentRef, id);
      case _PlayerMenuAction.speed:
        showSpeedSheet(parentContext, audio);
    }
  }
}
