import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/playlists/models/playlist_display_name.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/playlist_name_dialog.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 播放清單列表:本地音樂、我的最愛、最近播放等系統清單固定在最前,
/// 可新增 / 重新命名 / 刪除其他使用者清單。
/// 「本地音樂」是虛擬清單(不落地 Isar):內容即裝置音樂庫,唯讀。
class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showPlaylistNameDialog(
      context,
      title: l10n.playlist_new,
    );
    if (name == null) return;
    final id = await ref.read(playlistRepositoryProvider).create(name);
    if (!context.mounted) return;
    context.push('/playlists/$id');
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    PlaylistEntity playlist,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showPlaylistNameDialog(
      context,
      title: l10n.playlist_rename,
      initialName: playlist.name,
    );
    if (name == null) return;
    await ref.read(playlistRepositoryProvider).rename(playlist.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PlaylistEntity playlist,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlist_delete),
        content: Text(l10n.playlist_delete_confirm(playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(playlistRepositoryProvider).delete(playlist.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final libraryCount = ref.watch(musicLibraryProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tab_playlists)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        tooltip: l10n.playlist_new,
        child: const Icon(Icons.add),
      ),
      body: playlists.isEmpty
          ? Center(child: Text(l10n.playlists_empty))
          : ListView.builder(
              itemCount: playlists.length + 1,
              itemBuilder: (context, index) {
                // 「本地音樂」虛擬清單固定在最上,其餘清單依序往後排。
                if (index == 0) {
                  return ListTile(
                    minTileHeight: 48,
                    contentPadding: const EdgeInsetsDirectional.only(start: 16),
                    leading: const CircleAvatar(
                      child: Icon(Icons.library_music),
                    ),
                    title: Text(
                      l10n.playlist_local_music,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(l10n.playlist_track_count(libraryCount)),
                    onTap: () => context.push('/playlists/local'),
                  );
                }
                final playlist = playlists[index - 1];
                final trackCount = playlist.isRecentlyPlayed
                    ? playlist.recentlyPlayed.length
                    : playlist.trackIds.length;
                return ListTile(
                  minTileHeight: 48,
                  // 預設左右各 16;去掉右側留白,讓 trailing 選單貼齊右緣。
                  contentPadding: const EdgeInsetsDirectional.only(start: 16),
                  leading: playlist.isFavorites
                      ? const CircleAvatar(child: Icon(Icons.favorite))
                      : playlist.isRecentlyPlayed
                      ? const CircleAvatar(child: Icon(Icons.history))
                      : null,
                  title: Text(
                    playlistDisplayName(playlist, l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(l10n.playlist_track_count(trackCount)),
                  trailing: playlist.isFavorites || playlist.isRecentlyPlayed
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              _rename(context, ref, playlist);
                            } else if (value == 'delete') {
                              _delete(context, ref, playlist);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(l10n.playlist_rename),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(l10n.playlist_delete),
                            ),
                          ],
                        ),
                  onTap: () => context.push('/playlists/${playlist.id}'),
                );
              },
            ),
    );
  }
}
