import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/lyrics/services/lyrics_import_service.dart';
import 'package:seek_player/features/player/widgets/lyrics_edit_page.dart';
import 'package:seek_player/features/player/widgets/lyrics_view.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';
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

  /// 進該工具的編輯頁,並取代本選曲頁:編輯頁返回直接回工具頁。
  /// id 是 trackId;暫時曲目的 trackId 是 content URI(含 `/`),編碼後才能放進路徑參數。
  /// [source] 為選曲方式:清單點選([AnalyticsSource.list])或從檔案挑選
  /// ([AnalyticsSource.file])。
  void _open(Track track, {required AnalyticsSource source}) {
    logAnalyticsAction(
      ToolsAction.openEditor,
      source: source,
      option: widget.tool,
    );
    context.pushReplacement(
      '/tools/${widget.tool.name}/${Uri.encodeComponent(track.trackId)}',
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
    logAnalyticsAction(
      ToolsAction.pickFromFile,
      option: widget.tool,
      result: switch (result) {
        TrackFileCancelled() => AnalyticsResult.cancelled,
        TrackFileFound() => AnalyticsResult.success,
        TrackFileImportFailed() => AnalyticsResult.failure,
      },
    );
    switch (result) {
      case TrackFileCancelled():
        break;
      case TrackFileFound(:final track, :final imported):
        if (imported) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.tools_file_imported)),
          );
        }
        _open(track, source: AnalyticsSource.file);
      case TrackFileImportFailed():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.tools_file_import_failed)),
        );
    }
  }

  /// 工具「編輯歌詞」:不選曲目,直接開歌詞檔(如 `A-1.lrc`)進編輯頁。
  /// 編輯頁疊在本頁上,返回回到選曲頁。
  Future<void> _openLyricsFile() async {
    final l10n = AppLocalizations.of(context)!;
    final ({String name, String content})? picked;
    try {
      picked = await ref.read(lyricsImportServiceProvider).pickFile();
    } on LyricsImportException catch (e, s) {
      logAnalyticsAction(ToolsAction.openLyricsFile, result: e.error);
      reportError(e, s, reason: '工具開啟歌詞檔失敗（${e.error.name}）');
      showAppToast(lyricsImportErrorText(l10n, e.error));
      return;
    }
    logAnalyticsAction(
      ToolsAction.openLyricsFile,
      result: picked == null
          ? AnalyticsResult.cancelled
          : AnalyticsResult.success,
    );
    if (picked == null || !mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => LyricsEditPage(
          trackId: null,
          title: picked!.name,
          initialContent: picked.content,
        ),
      ),
    );
  }

  Future<void> _editSort() async {
    final sort = await showTrackSortSheet(context, current: _sort);
    if (sort == null) return;
    logAnalyticsAction(
      ToolsAction.changeSort,
      source: AnalyticsSource.toolPicker,
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
          ToolsAction.search,
          source: AnalyticsSource.toolPicker,
        );
      }
      _searchController.clear();
    }
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
              : Text(l10n.tools_select_audio),
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
                      onSelected: (path) {
                        // option = 是否選「全部」;不送資料夾路徑。
                        logAnalyticsAction(
                          ToolsAction.filterFolder,
                          source: AnalyticsSource.toolPicker,
                          option: path == null,
                        );
                        setState(() => _folder = path);
                      },
                    ),
                    onSearch: _toggleSearch,
                    onSort: _editSort,
                    actions: [
                      // 「編輯歌詞」從檔案選擇的是歌詞檔(直接編輯),
                      // 其他工具選的是音檔(對回曲庫中的曲目)。
                      if (widget.tool == ToolKind.lyricsEdit)
                        IconButton(
                          icon: const Icon(Icons.folder_outlined),
                          tooltip: l10n.lyrics_edit_open_file,
                          onPressed: _openLyricsFile,
                        )
                      else
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
                                key: ValueKey(track.trackId),
                                track: track,
                                stat: stats[track.filePath],
                                audio: audio,
                                onTap: () =>
                                    _open(track, source: AnalyticsSource.list),
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
