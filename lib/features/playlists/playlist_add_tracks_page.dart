import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/playlist_add_tracks_list.dart';
import 'package:seek_player/features/playlists/widgets/playlist_edit_tracks_list.dart';
import 'package:seek_player/features/tools/models/track_file_stat.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';
import 'package:seek_player/features/tools/providers/track_file_stats_provider.dart';
import 'package:seek_player/features/tools/providers/track_play_stats_provider.dart';
import 'package:seek_player/features/tools/widgets/folder_menu_button.dart';
import 'package:seek_player/features/tools/widgets/track_picker_toolbar.dart';
import 'package:seek_player/features/tools/widgets/track_search_field.dart';
import 'package:seek_player/features/tools/widgets/track_sort_sheet.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 由右至左滑入全螢幕「新增至這個播放清單」頁(page route,開法比照
/// 全螢幕播放頁的 `PlayerPageController.open`,僅滑入方向不同)。
///
/// [reorderable] 為 true 時顯示可拖曳排序的「編輯播放清單」版面
/// ([PlaylistEditTracksList]),只列出已加入的曲目；
/// 否則為單純新增/移除曲目的「增加項目」版面([PlaylistAddTracksList]),
/// 只列出進入本頁「當下」尚未加入的曲目
/// （進頁後的快照,頁面內加入/移除都不會讓項目消失或重新出現）。
/// 兩種版面上方都有資料夾 / 搜尋 / 排序工具列。
Future<void> showPlaylistAddTracksPage(
  BuildContext context,
  int playlistId, {
  bool reorderable = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) =>
          PlaylistAddTracksPage(
            playlistId: playlistId,
            reorderable: reorderable,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          ),
    ),
  );
}

/// 列出整個音樂庫供挑選加入 [playlistId]。
class PlaylistAddTracksPage extends ConsumerStatefulWidget {
  const PlaylistAddTracksPage({
    super.key,
    required this.playlistId,
    this.reorderable = false,
  });

  final int playlistId;
  final bool reorderable;

  @override
  ConsumerState<PlaylistAddTracksPage> createState() =>
      _PlaylistAddTracksPageState();
}

class _PlaylistAddTracksPageState extends ConsumerState<PlaylistAddTracksPage> {
  /// 進入「增加項目」頁面當下尚未加入的曲目快照；固定不隨後續加入/移除變動,
  /// 讓使用者能在同一份清單裡自由切換加入/移除,不會因為狀態改變而消失。
  late final List<Track> _initialNotAddedTracks;

  /// 資料夾篩選路徑;null 代表全部。
  String? _folder;

  /// 「編輯播放清單」預設依清單順序(可拖曳);「增加項目」依加入時間。
  late var _sort = widget.reorderable
      ? const TrackSort(field: TrackSortField.custom)
      : const TrackSort();
  var _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tracks = ref.read(musicLibraryProvider).valueOrNull ?? const [];
    final playlists = ref.read(playlistsProvider).valueOrNull ?? const [];
    final playlist = playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;
    final addedIds = playlist?.trackIds.toSet() ?? const <String>{};
    _initialNotAddedTracks = tracks
        .where((t) => !addedIds.contains(t.id))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editSort() async {
    final sort = await showTrackSortSheet(
      context,
      current: _sort,
      // 「編輯播放清單」多提供清單順序(唯一可拖曳排序的排序方式)。
      fields: widget.reorderable ? TrackSortField.values : null,
    );
    if (sort != null && mounted) setState(() => _sort = sort);
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _searchController.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final playlist = playlists
        .where((p) => p.id == widget.playlistId)
        .firstOrNull;
    final trackIds = playlist?.trackIds ?? const <String>[];
    final addedIds = trackIds.toSet();
    final audio = ref.watch(audioPlayerServiceProvider);

    // 「編輯播放清單」只列出已加入的曲目，依既有順序排列，供拖曳調整；
    // 找不到對應曲目（檔案已刪除）者略過，與 playlistTracksProvider 行為一致。
    final tracksById = {for (final t in tracks) t.id: t};
    final addedTracks = <Track>[
      for (final id in trackIds)
        if (tracksById[id] != null) tracksById[id]!,
    ];

    void toggle(String trackId, bool added) {
      final repo = ref.read(playlistRepositoryProvider);
      if (added) {
        repo.removeTrack(widget.playlistId, trackId);
      } else {
        repo.addTrack(widget.playlistId, trackId);
      }
    }

    final searching = _searching;

    return PopScope(
      // 搜尋中按返回只關閉搜尋、回到原本的頂欄,不離開本頁。
      canPop: !searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          // 由右至左滑入的頁面,以標準返回鍵收回本頁;搜尋中只關閉搜尋。
          leading: searching
              ? BackButton(onPressed: _toggleSearch)
              : const BackButton(),
          // 搜尋欄緊鄰返回鍵:返回鍵縮到最小點擊尺寸 48,並取消標題間距。
          leadingWidth: searching ? 48 : null,
          titleSpacing: searching ? 0 : null,
          title: searching
              ? TrackSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                )
              : Text(
                  widget.reorderable
                      ? l10n.playlist_edit_tracks
                      : l10n.playlist_add_tracks,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          // 搜尋欄右側留白,不貼齊螢幕邊緣。
          actions: [if (searching) const SizedBox(width: 16)],
        ),
        body: tracks.isEmpty
            ? _EmptyMessage(text: l10n.music_empty)
            : SafeArea(
                top: false,
                child: widget.reorderable
                    ? (addedTracks.isEmpty
                          ? _EmptyMessage(text: l10n.playlist_empty)
                          : _buildFilteredList(
                              l10n,
                              source: addedTracks,
                              listBuilder: (visible, reorderable) =>
                                  PlaylistEditTracksList(
                                    playlistId: widget.playlistId,
                                    addedTracks: visible,
                                    audio: audio,
                                    reorderable: reorderable,
                                    onRemove: (trackId) =>
                                        toggle(trackId, true),
                                  ),
                            ))
                    : (_initialNotAddedTracks.isEmpty
                          ? _EmptyMessage(text: l10n.playlist_all_added)
                          : _buildFilteredList(
                              l10n,
                              source: _initialNotAddedTracks,
                              listBuilder: (visible, _) =>
                                  PlaylistAddTracksList(
                                    tracks: visible,
                                    addedIds: addedIds,
                                    audio: audio,
                                    onToggle: toggle,
                                  ),
                            )),
              ),
      ),
    );
  }

  /// 工具列(資料夾 / 搜尋 / 排序)+ 由 [source] 篩選、排序後的清單。
  /// [listBuilder] 的第二個參數為顯示內容是否等於完整清單順序
  /// (清單順序排序、全部資料夾、未搜尋),只有此時才能拖曳排序。
  Widget _buildFilteredList(
    AppLocalizations l10n, {
    required List<Track> source,
    required Widget Function(List<Track> visible, bool isFullOrder)
    listBuilder,
  }) {
    final stats = ref.watch(trackFileStatsProvider).valueOrNull ?? const {};
    final plays = ref.watch(trackPlayStatsProvider);
    final folders = TrackFolder.groupTracks(source);
    // 移除曲目後選中的資料夾可能已不存在,視為全部。
    final folder = folders.any((f) => f.path == _folder) ? _folder : null;
    final query = _searchController.text.trim().toLowerCase();
    final visibleTracks = _sort.apply(
      [
        for (final t in source)
          if ((folder == null || TrackFolder.dirOf(t.filePath) == folder) &&
              (query.isEmpty ||
                  t.title.toLowerCase().contains(query) ||
                  (t.artist?.toLowerCase().contains(query) ?? false)))
            t,
      ],
      stats,
      plays,
    );
    final isFullOrder =
        _sort.field == TrackSortField.custom && folder == null && query.isEmpty;

    return Column(
      children: [
        TrackPickerToolbar(
          folderButton: FolderMenuButton(
            folders: folders,
            totalCount: source.length,
            latestOf: (path) => latestModifiedIn(source, stats, path),
            selected: folder,
            onSelected: (path) => setState(() => _folder = path),
          ),
          onSearch: _toggleSearch,
          onSort: _editSort,
          actions: const [],
        ),
        Expanded(
          child: visibleTracks.isEmpty
              ? Center(child: Text(l10n.playlist_search_no_result))
              : listBuilder(visibleTracks, isFullOrder),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
