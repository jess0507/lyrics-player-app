import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/core/permissions/permission_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/widgets/track_actions_sheet.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 「本地音樂」系統清單:內容即裝置音樂庫全部曲目,不落地 Isar、不參與
/// 同步,直接由 music library 衍生。唯讀 — 不可新增 / 移除 / 排序,
/// 僅能重新掃描、播放全部、逐首播放、搜尋與開啟曲目操作選單
/// (加入清單、檢視資訊)。
class LocalMusicPlaylistPage extends ConsumerStatefulWidget {
  const LocalMusicPlaylistPage({super.key});

  @override
  ConsumerState<LocalMusicPlaylistPage> createState() =>
      _LocalMusicPlaylistPageState();
}

class _LocalMusicPlaylistPageState
    extends ConsumerState<LocalMusicPlaylistPage> {
  bool _scanning = false;

  /// 確保權限後重新掃描裝置音樂庫。
  Future<void> _rescan() async {
    final granted = await permissionService.ensureAudioPermission(context);
    if (!granted || !mounted) return;

    setState(() => _scanning = true);
    try {
      await ref.read(musicLibraryProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
    final scheme = Theme.of(context).colorScheme;

    final systemButtonStyle = TextButton.styleFrom(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.playlist_local_music,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (tracks.isNotEmpty)
            IconButton(
              tooltip: l10n.playlist_play_all,
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () =>
                  ref.read(playbackControllerProvider).playTracksAt(tracks, 0),
            ),
        ],
      ),
      body: Column(
        children: [
          // 重新掃描永遠可用(清單為空時最需要);搜尋在無曲目時沒有意義,
          // 不顯示。
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    style: systemButtonStyle,
                    onPressed: _scanning ? null : _rescan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(l10n.music_rescan),
                  ),
                  if (tracks.isNotEmpty)
                    TextButton.icon(
                      style: systemButtonStyle,
                      onPressed: () => context.push('/playlists/local/search'),
                      icon: const Icon(Icons.search),
                      label: Text(l10n.music_search),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.music_empty,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _buildTrackList(tracks),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(List<Track> tracks) {
    final audio = ref.watch(audioPlayerServiceProvider);
    return StreamBuilder<SequenceState?>(
      stream: audio.player.sequenceStateStream,
      builder: (context, snapshot) {
        final tag = snapshot.data?.currentSource?.tag;
        final currentId = tag is MediaItem ? tag.id : null;
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackListTile(
              key: ValueKey(track.id),
              track: track,
              audio: audio,
              isCurrent: track.id == currentId,
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => showTrackActionsSheet(context, ref, track),
              ),
              onTap: () => ref
                  .read(playbackControllerProvider)
                  .playTracksAt(tracks, index),
            );
          },
        );
      },
    );
  }
}
