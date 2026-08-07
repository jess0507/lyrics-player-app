import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/features/playlists/providers/playlist_search_query_provider.dart';
import 'package:seek_player/features/playlists/providers/playlist_search_results_provider.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/widgets/playlist_track_actions_sheet.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';

/// 曲目搜尋頁:從播放清單內容頁進入,輸入關鍵字後過濾該清單內的曲目。
/// [playlistId] 為 null 代表「本地音樂」虛擬清單,搜尋範圍是整個音樂庫。
class PlaylistSearchPage extends ConsumerStatefulWidget {
  const PlaylistSearchPage({super.key, required this.playlistId});

  final int? playlistId;

  @override
  ConsumerState<PlaylistSearchPage> createState() =>
      _PlaylistSearchPageState();
}

class _PlaylistSearchPageState extends ConsumerState<PlaylistSearchPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(playlistSearchQueryProvider.notifier).state = '';
  }

  Future<void> _play(Track track) async {
    await ref.read(playbackControllerProvider).playTrack(track);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.playlist_search_hint,
            border: InputBorder.none,
          ),
          onChanged: (value) =>
              ref.read(playlistSearchQueryProvider.notifier).state = value,
        ),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSearch,
                  ),
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final query = ref.watch(playlistSearchQueryProvider).trim();
    final results = ref.watch(playlistSearchResultsProvider(widget.playlistId));

    if (query.isEmpty) {
      return _SearchHint(message: l10n.playlist_search_hint);
    }
    if (results.isEmpty) {
      return _SearchHint(message: l10n.playlist_search_no_result);
    }

    // 「最近播放」「本地音樂」是唯讀系統清單,動作選單不提供「從清單移除」。
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final isRecentlyPlayed = playlists
            .where((p) => p.id == widget.playlistId)
            .firstOrNull
            ?.isRecentlyPlayed ??
        false;
    final removablePlaylistId = isRecentlyPlayed ? null : widget.playlistId;

    final audio = ref.watch(audioPlayerServiceProvider);
    return StreamBuilder<SequenceState?>(
      stream: audio.player.sequenceStateStream,
      builder: (context, snapshot) {
        final tag = snapshot.data?.currentSource?.tag;
        final currentId = tag is MediaItem ? tag.id : null;
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final track = results[index];
            return TrackListTile(
              track: track,
              audio: audio,
              isCurrent: track.id == currentId,
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => showPlaylistTrackActionsSheet(
                  context,
                  ref,
                  track,
                  playlistId: removablePlaylistId,
                ),
              ),
              onTap: () => _play(track),
            );
          },
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
