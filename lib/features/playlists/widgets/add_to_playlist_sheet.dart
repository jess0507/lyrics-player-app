import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../music_list/models/track.dart';
import '../models/playlist_display_name.dart';
import '../services/playlist_repository.dart';
import '../providers/playlists_provider.dart';
import 'playlist_name_dialog.dart';

/// 顯示「加入播放清單」底部表單:列出所有清單,點選即把 [track] 加入,
/// 並提供「新增播放清單」入口。
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _AddToPlaylistSheet(track: track),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.track});

  final Track track;

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    int playlistId,
    String displayName,
    bool alreadyIn,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    if (!alreadyIn) {
      await ref.read(playlistRepositoryProvider).addTrack(playlistId, track.id);
    }
    navigator.pop();
    showAppToast(
      alreadyIn
          ? l10n.playlist_already_added(displayName)
          : l10n.playlist_added(displayName),
    );
  }

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showPlaylistNameDialog(
      context,
      title: l10n.playlist_new,
    );
    if (name == null || !context.mounted) return;
    final id = await ref.read(playlistRepositoryProvider).create(name);
    if (!context.mounted) return;
    await _add(context, ref, id, name, false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // 「最近播放」由播放行為自動維護,不開放手動加入。
    final playlists = (ref.watch(playlistsProvider).valueOrNull ?? const [])
        .where((p) => !p.isRecentlyPlayed)
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l10n.playlist_new),
            onTap: () => _createAndAdd(context, ref),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final displayName = playlistDisplayName(playlist, l10n);
                final alreadyIn = playlist.trackIds.contains(track.id);
                return ListTile(
                  leading: Icon(
                    playlist.isFavorites ? Icons.favorite : Icons.queue_music,
                  ),
                  title: Text(displayName, maxLines: 1),
                  trailing: alreadyIn ? const Icon(Icons.check) : null,
                  onTap: () =>
                      _add(context, ref, playlist.id, displayName, alreadyIn),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
