import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';
import 'package:seek_player/features/tools/models/track_file_stat.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';
import 'package:seek_player/features/tools/providers/track_file_stats_provider.dart';
import 'package:seek_player/features/tools/providers/track_play_stats_provider.dart';
import 'package:seek_player/features/tools/services/track_file_matcher.dart';
import 'package:seek_player/features/tools/widgets/track_picker_tile.dart';
import 'package:seek_player/features/tools/widgets/track_picker_toolbar.dart';
import 'package:seek_player/features/tools/widgets/track_search_field.dart';
import 'package:seek_player/features/tools/widgets/folder_menu_button.dart';
import 'package:seek_player/features/tools/widgets/track_sort_sheet.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具的選曲頁:列出本地音樂,可依資料夾篩選、搜尋、排序,
/// 或從系統選檔器挑檔(對回曲庫中的曲目);點曲目後進 [tool] 的編輯頁。
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
  var _sort = const TrackSort();
  var _searching = false;

  /// 選檔後比對 / 匯入中;顯示進度條並擋住重複觸發。
  var _picking = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 進該工具的編輯頁。id 可能是 iOS 的檔案路徑(含 `/`),
  /// 編碼後才能放進路徑參數。
  void _open(Track track) {
    context.push(
      '/tools/${widget.tool.name}/${Uri.encodeComponent(track.id)}',
      extra: track,
    );
  }

  Future<void> _pickFromFiles() async {
    setState(() => _picking = true);
    final TrackFileMatch result;
    try {
      result = await ref.read(trackFileMatcherProvider).pickAndMatch();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case TrackFileCancelled():
        break;
      case TrackFileFound(:final track, :final imported):
        if (imported) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.tools_file_imported)),
          );
        }
        _open(track);
      case TrackFileImportFailed():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.tools_file_import_failed)),
        );
    }
  }

  Future<void> _editSort() async {
    final sort = await showTrackSortSheet(context, current: _sort);
    if (sort != null && mounted) setState(() => _sort = sort);
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _searchController.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final audio = ref.watch(audioPlayerServiceProvider);
    final library = ref.watch(musicLibraryProvider);
    final tracks = library.valueOrNull ?? const [];
    final stats = ref.watch(trackFileStatsProvider).valueOrNull ?? const {};
    final plays = ref.watch(trackPlayStatsProvider);
    final folders = TrackFolder.groupTracks(tracks);
    // 重新掃描後選中的資料夾可能已不存在,視為全部。
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
              : Text(widget.tool.label(l10n)),
          // 搜尋欄右側留白,不貼齊螢幕邊緣。
          actions: [if (_searching) const SizedBox(width: 16)],
        ),
        body: tracks.isEmpty
            ? Center(
                // 匯入後重掃時曲庫短暫為空,顯示讀取中而非「尚無音樂」。
                child: library.isLoading
                    ? const CircularProgressIndicator()
                    : Text(l10n.music_empty),
              )
            : Column(
                children: [
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
                        icon: const Icon(Icons.folder_outlined),
                        tooltip: l10n.tools_pick_from_files,
                        onPressed: _picking ? null : _pickFromFiles,
                      ),
                    ],
                  ),
                  if (_picking) const LinearProgressIndicator(),
                  Expanded(
                    child: visibleTracks.isEmpty
                        ? Center(child: Text(l10n.playlist_search_no_result))
                        : ListView.builder(
                            itemCount: visibleTracks.length,
                            itemBuilder: (context, index) {
                              final track = visibleTracks[index];
                              return TrackPickerTile(
                                key: ValueKey(track.id),
                                track: track,
                                stat: stats[track.filePath],
                                audio: audio,
                                onTap: () => _open(track),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
