import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/playlist_edit_tracks_list.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 由下往上展開全螢幕「新增至這個播放清單」頁(開法同 PlayerPage)。
///
/// [reorderable] 為 true 時顯示可拖曳排序的「編輯播放清單」版面
/// ([PlaylistEditTracksList]),只列出已加入的曲目；
/// 否則為單純新增/移除曲目的「增加項目」版面(見 [_buildSimpleList]),
/// 只列出進入本頁「當下」尚未加入的曲目
/// （進頁後的快照,頁面內加入/移除都不會讓項目消失或重新出現）。
Future<void> showPlaylistAddTracksSheet(
  BuildContext context,
  int playlistId, {
  bool reorderable = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    // 滿版:不留 safe area 空隙、不加圓角,覆蓋整個螢幕(含狀態列區)。
    // 內容的上 / 下系統列留白由頁面自行處理。
    useSafeArea: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(),
    builder: (_) => FractionallySizedBox(
      heightFactor: 1,
      child: PlaylistAddTracksPage(
        playlistId: playlistId,
        reorderable: reorderable,
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

    // 滿版 sheet(useSafeArea: false)會被 Flutter 以 removeTop 清掉頂部
    // inset,須從底層 View 讀回硬體 padding,讓 AppBar 落在狀態列下方。
    final media = MediaQuery.of(context);
    final devicePadding = MediaQueryData.fromView(View.of(context)).padding;
    final restoredMedia = media.copyWith(
      padding: media.padding.copyWith(top: devicePadding.top),
    );

    return MediaQuery(
      data: restoredMedia,
      child: Scaffold(
        appBar: AppBar(
          // 左上往下的箭頭:點擊收回本頁。
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.reorderable
                ? l10n.playlist_edit_tracks
                : l10n.playlist_add_tracks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: tracks.isEmpty
            ? _EmptyMessage(text: l10n.music_empty)
            : SafeArea(
                top: false,
                child: widget.reorderable
                    ? (addedTracks.isEmpty
                          ? _EmptyMessage(text: l10n.playlist_empty)
                          : PlaylistEditTracksList(
                              playlistId: widget.playlistId,
                              addedTracks: addedTracks,
                              audio: audio,
                              onRemove: (trackId) => toggle(trackId, true),
                            ))
                    : (_initialNotAddedTracks.isEmpty
                          ? _EmptyMessage(text: l10n.playlist_all_added)
                          : _buildSimpleList(
                              context,
                              addedIds: addedIds,
                              audio: audio,
                              onToggle: toggle,
                            )),
              ),
      ),
    );
  }

  /// 「增加項目」清單:[_initialNotAddedTracks] 固定不變,點擊「+」加入、
  /// 已加入顯示打勾可再點一次移除;清單內容本身不會因為加入/移除而變動,
  /// 只有圖示狀態隨 [addedIds] 即時更新。
  Widget _buildSimpleList(
    BuildContext context, {
    required Set<String> addedIds,
    required AudioPlayerService audio,
    required void Function(String trackId, bool added) onToggle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      itemCount: _initialNotAddedTracks.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final track = _initialNotAddedTracks[index];
        final added = addedIds.contains(track.id);
        return TrackListTile(
          track: track,
          audio: audio,
          contentPadding: const EdgeInsets.only(left: 16.0),
          trailing: IconButton(
            icon: added
                ? Icon(Icons.check, color: scheme.primary)
                : const Icon(Icons.add),
            onPressed: () => onToggle(track.id, added),
          ),
          onTap: () => onToggle(track.id, added),
        );
      },
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
