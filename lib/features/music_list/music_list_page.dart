import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/filtered_tracks_provider.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/providers/music_search_query_provider.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/core/permissions/permission_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/track_list_tile.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/features/music_list/widgets/track_actions_sheet.dart';

class MusicListPage extends ConsumerStatefulWidget {
  const MusicListPage({super.key});

  @override
  ConsumerState<MusicListPage> createState() => _MusicListPageState();
}

class _MusicListPageState extends ConsumerState<MusicListPage> {
  bool _scanning = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(musicSearchQueryProvider.notifier).state = '';
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

  Future<void> _play(Track track) async {
    // 點擊播放後只在底部顯示 mini player，不自動展開全螢幕 PlayerPage。
    await ref.read(playbackControllerProvider).playTrack(track);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final libraryAsync = ref.watch(musicLibraryProvider);
    final tracks = ref.watch(filteredTracksProvider);
    final hasLibrary = libraryAsync.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tab_music_list),
        actions: [
          IconButton(
            tooltip: l10n.music_rescan,
            onPressed: _scanning ? null : _rescan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
        bottom: hasLibrary
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) => SearchBar(
                      controller: _searchController,
                      elevation: const WidgetStatePropertyAll(0),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.only(left: 16, right: 4),
                      ),
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        maxHeight: 40,
                      ),
                      leading: const Icon(Icons.search),
                      trailing: value.text.isEmpty
                          ? null
                          : [
                              IconButton(
                                icon: const Icon(Icons.close),
                                visualDensity: VisualDensity.compact,
                                onPressed: _clearSearch,
                              ),
                            ],
                      hintText: l10n.music_search,
                      onChanged: (value) =>
                          ref.read(musicSearchQueryProvider.notifier).state =
                              value,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(l10n, libraryAsync, tracks),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    AsyncValue<List<Track>> libraryAsync,
    List<Track> tracks,
  ) {
    // 首次掃描中（尚無資料）顯示進度。
    if (libraryAsync.isLoading &&
        !(libraryAsync.valueOrNull?.isNotEmpty ?? false)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tracks.isEmpty) {
      return _EmptyState(
        message: l10n.music_empty,
        actionLabel: l10n.music_rescan,
        onAction: _scanning ? null : _rescan,
      );
    }
    final audio = ref.watch(audioPlayerServiceProvider);
    return StreamBuilder<SequenceState?>(
      stream: audio.player.sequenceStateStream,
      builder: (context, snapshot) {
        final tag = snapshot.data?.currentSource?.tag;
        final currentId = tag is MediaItem ? tag.id : null;
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isCurrent = track.id == currentId;
            return TrackListTile(
              track: track,
              audio: audio,
              isCurrent: isCurrent,
              trailing: IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => showTrackActionsSheet(context, ref, track),
              ),
              onTap: () => _play(track),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
