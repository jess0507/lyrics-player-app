import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/features/playlists/models/playlist_display_name.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/features/playlists/playlist_add_tracks_page.dart';
import 'package:seek_player/features/playlists/providers/playlist_tracks_provider.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/providers/recently_played_provider.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/playlist_track_actions_sheet.dart';
import 'package:seek_player/features/playlists/widgets/recently_played_track_list.dart';
import 'package:seek_player/features/tools/models/track_file_stat.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';
import 'package:seek_player/features/tools/providers/track_file_stats_provider.dart';
import 'package:seek_player/features/tools/providers/track_play_stats_provider.dart';
import 'package:seek_player/features/tools/widgets/folder_menu_button.dart';
import 'package:seek_player/features/tools/widgets/track_picker_toolbar.dart';
import 'package:seek_player/features/tools/widgets/track_search_field.dart';
import 'package:seek_player/features/tools/widgets/track_sort_sheet.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';

/// 單一播放清單內容:播放全部、逐首播放、移除、拖曳排序,
/// 以及依資料夾篩選、搜尋、排序。
class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  int get playlistId => widget.playlistId;

  /// 目前篩選的資料夾路徑;null 代表全部。
  String? _folder;

  /// 預設維持清單的自訂順序。
  var _sort = const TrackSort(field: TrackSortField.custom);
  var _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editSort() async {
    final sort = await showTrackSortSheet(
      context,
      current: _sort,
      fields: TrackSortField.values,
    );
    if (sort != null && mounted) setState(() => _sort = sort);
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _searchController.clear();
  });

  Future<void> _clearRecentlyPlayed() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlist_clear_recently_played),
        content: Text(l10n.playlist_clear_recently_played_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(playlistRepositoryProvider).clearRecentlyPlayed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    final title = playlist == null
        ? l10n.tab_playlists
        : playlistDisplayName(playlist, l10n);

    // 「最近播放」是系統清單:不可增加項目 / 排序 / 逐首移除,只能整份清除。
    if (playlist?.isRecentlyPlayed ?? false) {
      final recentlyPlayed = ref.watch(recentlyPlayedProvider);
      return Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (recentlyPlayed.isNotEmpty)
              IconButton(
                tooltip: l10n.playlist_clear_recently_played,
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: _clearRecentlyPlayed,
              ),
          ],
        ),
        body: Column(
          children: [
            if (recentlyPlayed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        context.push('/playlists/$playlistId/search'),
                    icon: SvgIcon(Assets.icon.search),
                    label: Text(l10n.music_search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Expanded(child: RecentlyPlayedTrackList()),
          ],
        ),
      );
    }

    final tracks = ref.watch(playlistTracksProvider(playlistId));
    final stats = ref.watch(trackFileStatsProvider).valueOrNull ?? const {};
    final plays = ref.watch(trackPlayStatsProvider);
    final folders = TrackFolder.groupTracks(tracks);
    // 曲目被移除後選中的資料夾可能已不存在,視為全部。
    final folder = folders.any((f) => f.path == _folder) ? _folder : null;
    final query = _searchController.text.trim().toLowerCase();
    final visibleTracks = _sort.apply(
      [
        for (final t in tracks)
          if ((folder == null || TrackFolder.dirOf(t.filePath) == folder) &&
              (query.isEmpty ||
                  t.title.toLowerCase().contains(query) ||
                  (t.artist?.toLowerCase().contains(query) ?? false)))
            t,
      ],
      stats,
      plays,
    );
    // 只有顯示完整清單的自訂順序時才能拖曳,否則拖曳位置無法對回清單。
    final reorderable =
        _sort.field == TrackSortField.custom && folder == null && query.isEmpty;

    return PopScope(
      // 搜尋中按返回只關閉搜尋、回到原本的頂欄,不離開本頁。
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          // 搜尋中的返回只關閉搜尋,不離開本頁。
          leading: _searching ? BackButton(onPressed: _toggleSearch) : null,
          // 搜尋欄緊鄰返回鍵:返回鍵縮到最小點擊尺寸 48(預設 56 會在
          // 箭頭右側多出空白),並取消標題間距。
          leadingWidth: _searching ? 48 : null,
          titleSpacing: _searching ? 0 : null,
          title: _searching
              ? TrackSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                )
              : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          // 搜尋欄右側留白,不貼齊螢幕邊緣。
          actions: [if (_searching) const SizedBox(width: 16)],
        ),
        // 全部播放改用 FAB,清單為空時不顯示;只播目前篩選出的曲目。
        floatingActionButton: visibleTracks.isEmpty
            ? null
            : FloatingActionButton(
                // 各分頁在 IndexedStack 中同時存在,共用預設 hero tag 會在推頁時
                // 衝突;FAB 不需要 hero 轉場,直接關掉。
                heroTag: null,
                tooltip: l10n.playlist_play_all,
                onPressed: () => ref
                    .read(playbackControllerProvider)
                    .playTracksAt(visibleTracks, 0),
                child: const Icon(Icons.play_arrow_rounded),
              ),
        body: Column(
          children: [
            // 新增、編輯都往上展開同一張挑選/排序曲目頁:
            // 新增曲目、或調整已加入曲目的順序。
            TrackPickerToolbar(
              folderButton: FolderMenuButton(
                folders: folders,
                totalCount: tracks.length,
                latestOf: (path) => latestModifiedIn(tracks, stats, path),
                selected: folder,
                onSelected: (path) => setState(() => _folder = path),
              ),
              onSearch: _toggleSearch,
              onSort: _editSort,
              actions: [
                IconButton(
                  tooltip: l10n.playlist_add_item,
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      showPlaylistAddTracksPage(context, playlistId),
                ),
                // 清單為空時沒有項目可排序或刪除,停用編輯。
                IconButton(
                  tooltip: l10n.playlist_edit,
                  icon: const Icon(Icons.edit),
                  onPressed: tracks.isEmpty
                      ? null
                      : () => showPlaylistAddTracksPage(
                          context,
                          playlistId,
                          reorderable: true,
                        ),
                ),
              ],
            ),
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.playlist_empty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : visibleTracks.isEmpty
                  ? Center(child: Text(l10n.playlist_search_no_result))
                  : _buildTrackList(visibleTracks, reorderable: reorderable),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(List<Track> tracks, {required bool reorderable}) {
    final audio = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<SequenceState?>(
      stream: audio.player.sequenceStateStream,
      builder: (context, snapshot) {
        final tag = snapshot.data?.currentSource?.tag;
        final currentId = tag is MediaItem ? tag.id : null;
        Widget itemBuilder(BuildContext context, int index) {
          final track = tracks[index];
          return TrackListTile(
            key: ValueKey(track.id),
            track: track,
            audio: audio,
            isCurrent: track.id == currentId,
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => showPlaylistTrackActionsSheet(
                context,
                ref,
                track,
                playlistId: playlistId,
              ),
            ),
            onTap: () => ref
                .read(playbackControllerProvider)
                .playTracksAt(tracks, index),
          );
        }

        // 底部留白讓最後一首能捲到 FAB(56 + 16 * 2)上方,不被蓋住。
        const padding = EdgeInsets.only(bottom: 88);
        if (!reorderable) {
          return ListView.builder(
            padding: padding,
            itemCount: tracks.length,
            itemBuilder: itemBuilder,
          );
        }
        return ReorderableListView.builder(
          padding: padding,
          itemCount: tracks.length,
          onReorderItem: (oldIndex, newIndex) {
            final ids = tracks.map((t) => t.id).toList();
            final moved = ids.removeAt(oldIndex);
            ids.insert(newIndex, moved);
            ref.read(playlistRepositoryProvider).setTrackIds(playlistId, ids);
          },
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
