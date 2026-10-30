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
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/features/playlists/widgets/local_music_folder_bar.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_logo_leading.dart';
import 'package:seek_player/shared/widgets/empty_state_view.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 「本地音樂」分頁(底部導覽第一個分頁):內容即裝置音樂庫全部曲目,不落地 Isar、不參與
/// 同步,直接由 music library 衍生。唯讀 — 不可新增 / 移除 / 排序,
/// 僅能重新掃描、依資料夾篩選、播放全部、逐首播放、搜尋與開啟曲目
/// 操作選單(加入清單、檢視資訊)。
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

  /// 目前篩選的資料夾路徑;null 代表全部。
  String? _folder;

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
    final folders = TrackFolder.groupTracks(tracks);
    // 重新掃描後選中的資料夾可能已不存在,視為全部。
    final folder = folders.any((f) => f.path == _folder) ? _folder : null;
    final visibleTracks = folder == null
        ? tracks
        : [
            for (final t in tracks)
              if (TrackFolder.dirOf(t.filePath) == folder) t,
          ];
    final scheme = Theme.of(context).colorScheme;

    final systemButtonStyle = TextButton.styleFrom(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Scaffold(
      appBar: AppBar(
        // 分頁根頁沒有返回鍵,左側改放 app 圖示。
        leading: const AppLogoLeading(),
        title: Text(
          l10n.playlist_local_music,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // 有曲目時搜尋與重新掃描放在頂欄右側;清單為空時重新掃描改由
        // 下方空狀態提供,搜尋則無意義,兩者都不顯示。
        actions: [
          if (tracks.isNotEmpty) ...[
            IconButton(
              tooltip: l10n.music_search,
              onPressed: () => context.push('/local/search'),
              icon: SvgIcon(Assets.icon.search),
            ),
            IconButton(
              tooltip: l10n.music_rescan,
              onPressed: _scanning ? null : _rescan,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ],
      ),
      // 全部播放改用 FAB,清單為空時不顯示;只播目前篩選出的曲目。
      floatingActionButton: visibleTracks.isEmpty
          ? null
          : FloatingActionButton(
              tooltip: l10n.playlist_play_all,
              onPressed: () => ref
                  .read(playbackControllerProvider)
                  .playTracksAt(visibleTracks, 0),
              child: const Icon(Icons.play_arrow_rounded),
            ),
      body: Column(
        children: [
          // iOS 音樂庫 = app Documents(方案 A),曲目由使用者匯入;
          // Android 掃 MediaStore,無匯入需求,整列連同留白一併隱藏。
          if (Platform.isIOS) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  style: systemButtonStyle,
                  onPressed: _importing ? null : _importMusic,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(l10n.music_import),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 曲目分散在兩個以上資料夾時才顯示篩選列。
          if (folders.length > 1)
            LocalMusicFolderBar(
              folders: folders,
              selected: folder,
              onSelected: (path) => setState(() => _folder = path),
            ),
          Expanded(
            child: tracks.isEmpty
                ? EmptyStateView(
                    message: Platform.isIOS
                        ? l10n.music_empty_import
                        : l10n.music_empty,
                    action: _rescanButton(systemButtonStyle, l10n),
                  )
                : _buildTrackList(visibleTracks),
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
          // 底部留白讓最後一首能捲到 FAB(56 + 16 * 2)上方,不被蓋住。
          padding: const EdgeInsets.only(bottom: 88),
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
