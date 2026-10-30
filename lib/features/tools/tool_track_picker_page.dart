import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/player/widgets/lyrics_actions_sheet.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/features/playlists/widgets/local_music_folder_bar.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';
import 'package:seek_player/features/tools/widgets/cover_actions_sheet.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 工具的選曲頁:列出本地音樂(可依資料夾篩選),點曲目開啟 [tool] 的動作表單。
/// 點曲目不播放,只對該曲執行工具。
class ToolTrackPickerPage extends ConsumerStatefulWidget {
  const ToolTrackPickerPage({super.key, required this.tool});

  final ToolKind tool;

  @override
  ConsumerState<ToolTrackPickerPage> createState() =>
      _ToolTrackPickerPageState();
}

class _ToolTrackPickerPageState extends ConsumerState<ToolTrackPickerPage> {
  /// 目前篩選的資料夾路徑;null 代表全部。
  String? _folder;

  void _open(Track track) {
    switch (widget.tool) {
      case ToolKind.lyrics:
        showLyricsActionsSheet(
          context,
          ref,
          trackId: track.id,
          title: track.title,
        );
      case ToolKind.cover:
        showCoverActionsSheet(context, ref, trackId: track.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final audio = ref.watch(audioPlayerServiceProvider);
    final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
    final folders = TrackFolder.groupTracks(tracks);
    // 重新掃描後選中的資料夾可能已不存在,視為全部。
    final folder = folders.any((f) => f.path == _folder) ? _folder : null;
    final visibleTracks = folder == null
        ? tracks
        : [
            for (final t in tracks)
              if (TrackFolder.dirOf(t.filePath) == folder) t,
          ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.tool.label(l10n))),
      body: tracks.isEmpty
          ? Center(child: Text(l10n.music_empty))
          : Column(
              children: [
                // 曲目分散在兩個以上資料夾時才顯示篩選列。
                if (folders.length > 1)
                  LocalMusicFolderBar(
                    folders: folders,
                    selected: folder,
                    onSelected: (path) => setState(() => _folder = path),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: visibleTracks.length,
                    itemBuilder: (context, index) {
                      final track = visibleTracks[index];
                      return TrackListTile(
                        key: ValueKey(track.id),
                        track: track,
                        audio: audio,
                        trailing: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 16),
                          child: Icon(widget.tool.icon),
                        ),
                        onTap: () => _open(track),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
