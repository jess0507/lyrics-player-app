import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/output/providers/output_lyrics_tracks_provider.dart';
import 'package:seek_player/features/output/widgets/output_track_list.dart';
import 'package:seek_player/features/playlists/widgets/playlist_action_bar.dart';
import 'package:seek_player/features/playlists/widgets/playlist_play_controls.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';
import 'package:seek_player/features/tools/providers/track_file_stats_provider.dart';
import 'package:seek_player/features/tools/providers/track_play_stats_provider.dart';
import 'package:seek_player/features/tools/widgets/track_search_field.dart';
import 'package:seek_player/features/tools/widgets/track_sort_sheet.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';

/// 「Output → 歌詞」:列出有歌詞的曲目,點選播放並顯示滿版歌詞。
/// 頂欄右側的更多按鈕開啟排序 / 搜尋選單;清單上方右側為隨機 / 播放全部
/// (同播放清單頁)。
class OutputLyricsPage extends ConsumerStatefulWidget {
  const OutputLyricsPage({super.key});

  @override
  ConsumerState<OutputLyricsPage> createState() => _OutputLyricsPageState();
}

class _OutputLyricsPageState extends ConsumerState<OutputLyricsPage> {
  /// 預設加入時間新到舊;僅本頁暫存。
  var _sort = const TrackSort();
  var _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editSort() async {
    final sort = await showTrackSortSheet(context, current: _sort);
    if (sort == null) return;
    logAnalyticsAction(
      PlaylistAction.changeSort,
      source: AnalyticsSource.outputLyrics,
      option: sort.field,
    );
    if (mounted) setState(() => _sort = sort);
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) {
      // 離開搜尋時才記(不送搜尋字)。
      if (_searchController.text.trim().isNotEmpty) {
        logAnalyticsAction(
          PlaylistAction.search,
          source: AnalyticsSource.outputLyrics,
        );
      }
      _searchController.clear();
    }
  });

  void _onMenuSelected(_MoreAction action) => switch (action) {
    _MoreAction.sort => _editSort(),
    _MoreAction.search => _toggleSearch(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tracks = ref.watch(outputLyricsTracksProvider);
    final stats = ref.watch(trackFileStatsProvider).valueOrNull ?? const {};
    final plays = ref.watch(trackPlayStatsProvider);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = [
      for (final t in tracks)
        if (query.isEmpty ||
            t.title.toLowerCase().contains(query) ||
            (t.artist?.toLowerCase().contains(query) ?? false))
          t,
    ];
    // 本頁的「加入時間」指歌詞加入時間,即 provider 的順序(新到舊),
    // 不用 TrackSort 的檔案修改時間。
    final visibleTracks = _sort.field == TrackSortField.timeAdded
        ? (_sort.descending ? filtered : filtered.reversed.toList())
        : _sort.apply(filtered, stats, plays);
    return PopScope(
      // 搜尋中按返回只關閉搜尋、回到原本的頂欄,不離開本頁。
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleSearch();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _searching ? BackButton(onPressed: _toggleSearch) : null,
          // 搜尋欄緊鄰返回鍵(同播放清單頁)。
          leadingWidth: _searching ? 48 : null,
          titleSpacing: _searching ? 0 : null,
          title: _searching
              ? TrackSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                )
              : Text(l10n.output_lyrics),
          actions: [
            if (_searching)
              // 搜尋欄右側留白,不貼齊螢幕邊緣。
              const SizedBox(width: 16)
            // 沒有曲目時沒有東西可排序 / 搜尋 / 播放,不顯示。
            else if (tracks.isNotEmpty)
              PopupMenuButton<_MoreAction>(
                icon: const Icon(Icons.more_vert),
                onSelected: _onMenuSelected,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _MoreAction.sort,
                    child: ListTile(
                      leading: const Icon(Icons.sort),
                      title: Text(l10n.tools_sort_by),
                    ),
                  ),
                  PopupMenuItem(
                    value: _MoreAction.search,
                    child: ListTile(
                      leading: SvgIcon(Assets.icon.search),
                      title: Text(l10n.music_search),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: tracks.isEmpty
            ? Center(child: Text(l10n.output_lyrics_empty))
            : Column(
                children: [
                  // 搜尋無結果時不顯示隨機 / 播放;只播目前篩選出的曲目。
                  if (visibleTracks.isNotEmpty)
                    PlaylistActionBar(
                      actions: const [],
                      trailing: PlaylistPlayControls(
                        tracks: visibleTracks,
                        source: AnalyticsSource.outputLyrics,
                      ),
                    ),
                  Expanded(
                    child: visibleTracks.isEmpty
                        ? Center(child: Text(l10n.playlist_search_no_result))
                        : OutputTrackList(
                            tracks: visibleTracks,
                            source: AnalyticsSource.outputLyrics,
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 頂欄更多選單的項目。
enum _MoreAction { sort, search }
