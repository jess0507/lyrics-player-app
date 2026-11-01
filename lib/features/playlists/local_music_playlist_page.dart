import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:seek_player/features/tools/models/track_file_stat.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';
import 'package:seek_player/features/tools/providers/track_file_stats_provider.dart';
import 'package:seek_player/features/tools/providers/track_play_stats_provider.dart';
import 'package:seek_player/features/tools/widgets/folder_menu_button.dart';
import 'package:seek_player/features/tools/widgets/track_picker_toolbar.dart';
import 'package:seek_player/features/tools/widgets/track_search_field.dart';
import 'package:seek_player/features/tools/widgets/track_sort_sheet.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_logo_leading.dart';
import 'package:seek_player/shared/widgets/empty_state_view.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 「本地音樂」分頁(底部導覽第一個分頁):內容即裝置音樂庫全部曲目,不落地 Isar、不參與
/// 同步,直接由 music library 衍生。唯讀 — 不可新增 / 移除 / 手動調整順序,
/// 僅能重新掃描、依資料夾篩選、搜尋、排序、播放全部、逐首播放與開啟曲目
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
  var _sort = const TrackSort();
  var _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRescanIfEmpty());
  }

  /// 進入本頁時,若首次載入後音樂庫為空(多半是尚未授權,build 不主動
  /// 彈權限),自動走一次「請求權限 → 重新掃描」。iOS 掃自家沙盒、無需
  /// 權限,build 已掃過,空清單代表尚未匯入,不重複掃描。
  Future<void> _autoRescanIfEmpty() async {
    if (Platform.isIOS) return;
    final List<Track> tracks;
    try {
      tracks = await ref.read(musicLibraryProvider.future);
    } catch (_) {
      return;
    }
    if (tracks.isEmpty && mounted && !_scanning) await _rescan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _editSort() async {
    final sort = await showTrackSortSheet(context, current: _sort);
    if (sort != null && mounted) setState(() => _sort = sort);
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _searchController.clear();
  });

  /// 僅在本分頁可見(IndexedStack 中非作用分頁的 TickerMode 為關)、
  /// 本頁在最上層且正在搜尋時處理返回;其餘交回預設行為。
  Future<bool> _onBackButtonPressed() async {
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!_searching || !visible) return false;
    _toggleSearch();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(musicLibraryProvider);
    final tracks = library.valueOrNull ?? const [];
    // 掃描中(首次載入、匯入後或手動重新掃描)且清單為空時,中央改顯示
    // loading,不顯示空狀態與重新掃描按鈕。
    final scanning = _scanning || library.isLoading;
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
    final scheme = Theme.of(context).colorScheme;

    final systemButtonStyle = TextButton.styleFrom(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    // 搜尋中按返回只關閉搜尋、回到原本的頂欄。本頁是分頁根頁,
    // go_router 在分頁 navigator 無頁可退時直接交給 root navigator,
    // 不會經過本頁的 PopScope,因此改由 BackButtonListener 攔截。
    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: Scaffold(
        appBar: AppBar(
          // 分頁根頁沒有返回鍵,左側改放 app 圖示;搜尋中改為返回,
          // 按下關閉搜尋。
          leading: _searching
              ? BackButton(onPressed: _toggleSearch)
              : const AppLogoLeading(),
          // 搜尋欄緊鄰返回鍵:返回鍵縮到最小點擊尺寸 48(預設 56 會在
          // 箭頭右側多出空白),並取消標題間距。
          leadingWidth: _searching ? 48 : null,
          titleSpacing: _searching ? 0 : null,
          title: _searching
              ? TrackSearchField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                )
              : Text(
                  l10n.playlist_local_music,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
            // 有曲目時才顯示資料夾 / 搜尋 / 排序 / 重新掃描工具列;
            // 清單為空時重新掃描改由下方空狀態提供。
            if (tracks.isNotEmpty)
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
              ),
            Expanded(
              child: tracks.isEmpty && scanning
                  ? const Center(child: CircularProgressIndicator())
                  : tracks.isEmpty
                  ? EmptyStateView(
                      message: Platform.isIOS
                          ? l10n.music_empty_import
                          : l10n.music_empty,
                      action: _rescanButton(systemButtonStyle, l10n),
                    )
                  : visibleTracks.isEmpty
                  ? Center(child: Text(l10n.playlist_search_no_result))
                  : _buildTrackList(visibleTracks),
            ),
          ],
        ),
      ),
    );
  }

  /// 空狀態的重新掃描按鈕;掃描中整個空狀態會換成中央 loading,
  /// 因此這裡不需處理掃描中的狀態。
  Widget _rescanButton(ButtonStyle style, AppLocalizations l10n) {
    return TextButton.icon(
      style: style,
      onPressed: _rescan,
      icon: const Icon(Icons.refresh),
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
              onTap: () => ref
                  .read(playbackControllerProvider)
                  .playTracksAt(tracks, index),
              onLongPress: () => showTrackActionsSheet(context, ref, track),
            );
          },
        );
      },
    );
  }
}
