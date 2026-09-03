import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/core/permissions/permission_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/services/music_import_service.dart';
import 'package:seek_player/features/music_list/widgets/track_actions_sheet.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/empty_state_view.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';
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
  bool _importing = false;

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

  /// iOS:以文件選擇器匯入音訊檔到 app Documents,完成後重新掃描。
  Future<void> _importMusic() async {
    setState(() => _importing = true);
    try {
      final count = await ref
          .read(musicImportServiceProvider)
          .importFromPicker();
      if (count > 0) {
        await ref.read(musicLibraryProvider.notifier).refresh();
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.music_import_done(count))),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _importing = false);
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
          // 有曲目時顯示重新掃描與搜尋;清單為空時兩者都不放在這裡,
          // 重新掃描改由下方空狀態提供。Android 空清單時整列沒有按鈕,
          // 連同留白一併隱藏。
          if (Platform.isIOS || tracks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // iOS 音樂庫 = app Documents(方案 A),曲目由使用者匯入;
                    // Android 掃 MediaStore,無匯入需求。
                    if (Platform.isIOS)
                      TextButton.icon(
                        style: systemButtonStyle,
                        onPressed: _importing ? null : _importMusic,
                        icon: _importing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: Text(l10n.music_import),
                      ),
                    // 清單為空時重新掃描移到空狀態插圖下方,這裡不重複顯示。
                    if (tracks.isNotEmpty) ...[
                      _rescanButton(systemButtonStyle, l10n),
                      TextButton.icon(
                        style: systemButtonStyle,
                        onPressed: () =>
                            context.push('/playlists/local/search'),
                        icon: SvgIcon(Assets.icon.search),
                        label: Text(l10n.music_search),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: tracks.isEmpty
                ? EmptyStateView(
                    message: Platform.isIOS
                        ? l10n.music_empty_import
                        : l10n.music_empty,
                    action: _rescanButton(systemButtonStyle, l10n),
                  )
                : _buildTrackList(tracks),
          ),
        ],
      ),
    );
  }

  /// 重新掃描按鈕;掃描中顯示進度並停用。
  Widget _rescanButton(ButtonStyle style, AppLocalizations l10n) {
    return TextButton.icon(
      style: style,
      onPressed: _scanning ? null : _rescan,
      icon: _scanning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: Text(l10n.music_rescan),
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
