import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/features/playlists/models/playlist_display_name.dart';
import 'package:seek_player/features/playlists/playlist_add_tracks_page.dart';
import 'package:seek_player/features/playlists/providers/playlist_tracks_provider.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/providers/recently_played_provider.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/playlist_detail_header.dart';
import 'package:seek_player/features/playlists/widgets/playlist_track_actions_sheet.dart';
import 'package:seek_player/features/playlists/widgets/recently_played_track_list.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';
import 'package:seek_player/features/tools/providers/track_file_stats_provider.dart';
import 'package:seek_player/features/tools/providers/track_play_stats_provider.dart';
import 'package:seek_player/features/tools/widgets/track_search_field.dart';
import 'package:seek_player/features/tools/widgets/track_sort_sheet.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 單一播放清單內容:頂端靠左為清單名稱,其下一列新增 / 編輯 / 排序 / 搜尋
/// (最近播放為清空 / 搜尋),再下方為曲目清單;播放全部、逐首播放。
class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  int get playlistId => widget.playlistId;

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

    final title = playlist == null
        ? l10n.tab_playlists
        : playlistDisplayName(playlist, l10n);

    // 「最近播放」是系統清單:不可增加項目 / 拖曳排序 / 逐首移除,只能整份
    // 清除,也不提供排序(固定依播放時間);操作列只有清空與搜尋。
    final isRecentlyPlayed = playlist?.isRecentlyPlayed ?? false;
    final recentItems = isRecentlyPlayed
        ? ref.watch(recentlyPlayedProvider)
        : const <RecentlyPlayedItem>[];

    final tracks = isRecentlyPlayed
        ? [for (final item in recentItems) item.track]
        : ref.watch(playlistTracksProvider(playlistId));
    final stats = ref.watch(trackFileStatsProvider).valueOrNull ?? const {};
    final plays = ref.watch(trackPlayStatsProvider);
    final query = _searchController.text.trim().toLowerCase();
    final visibleTracks = _sort.apply(
      [
        for (final t in tracks)
          if (query.isEmpty ||
              t.title.toLowerCase().contains(query) ||
              (t.artist?.toLowerCase().contains(query) ?? false))
            t,
      ],
      stats,
      plays,
    );
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
          // 清單名稱改放內容區頂端,頂欄只有返回鍵;搜尋中放搜尋欄。
          title: _searching
              ? TrackSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                )
              : null,
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
            PlaylistDetailHeader(
              title: title,
              actions: [
                // 新增往上展開挑選曲目頁;最近播放不可增加項目。
                if (!isRecentlyPlayed)
                  IconButton(
                    tooltip: l10n.playlist_add_item,
                    icon: const Icon(Icons.add),
                    onPressed: () =>
                        showPlaylistAddTracksPage(context, playlistId),
                  ),
                // 清單為空時沒有東西可編輯 / 排序 / 搜尋 / 清空,不顯示。
                if (tracks.isNotEmpty) ...[
                  if (isRecentlyPlayed)
                    IconButton(
                      tooltip: l10n.playlist_clear_recently_played,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: _clearRecentlyPlayed,
                    )
                  else ...[
                    // 往上展開同一張挑選曲目頁,調整已加入曲目的順序。
                    IconButton(
                      tooltip: l10n.playlist_edit,
                      icon: const Icon(Icons.edit),
                      onPressed: () => showPlaylistAddTracksPage(
                        context,
                        playlistId,
                        reorderable: true,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.tools_sort_by,
                      icon: const Icon(Icons.sort),
                      onPressed: _editSort,
                    ),
                  ],
                  IconButton(
                    tooltip: l10n.music_search,
                    icon: SvgIcon(Assets.icon.search),
                    onPressed: _toggleSearch,
                  ),
                ],
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
                  : isRecentlyPlayed
                  ? _buildRecentlyPlayedList(recentItems, visibleTracks)
                  : _buildTrackList(visibleTracks),
            ),
          ],
        ),
      ),
    );
  }

  /// 最近播放:把篩選後的 [tracks] 對回播放紀錄,依播放時間新到舊、
  /// 按日期分組。
  Widget _buildRecentlyPlayedList(
    List<RecentlyPlayedItem> items,
    List<Track> tracks,
  ) {
    // 同曲重播會移到最前面,trackId 在最近播放中唯一。
    final byId = {for (final item in items) item.track.id: item};
    return RecentlyPlayedTrackList(
      items: [for (final t in tracks) byId[t.id]!],
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
              onTap: () => ref
                  .read(playbackControllerProvider)
                  .playTracksAt(tracks, index),
              onLongPress: () => showPlaylistTrackActionsSheet(
                context,
                ref,
                track,
                playlistId: playlistId,
              ),
            );
          },
        );
      },
    );
  }
}
