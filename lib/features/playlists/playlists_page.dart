import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/playlists/models/playlist_display_name.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/playlists/playlist_detail_page.dart';
import 'package:seek_player/features/playlists/providers/playlist_tracks_provider.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/providers/recently_played_provider.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/features/playlists/widgets/playlist_name_dialog.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_logo_leading.dart';

/// 「媒體庫」分頁的播放清單區塊:我的最愛、最近播放等系統清單固定在最前,
/// 可新增 / 重新命名 / 刪除其他使用者清單。
class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key, this.header});

  /// 頂欄下方的區塊切換列(見 LibraryPage)。
  final Widget? header;

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showPlaylistNameDialog(
      context,
      title: l10n.playlist_new,
    );
    if (name == null) return;
    logAnalyticsAction(
      PlaylistAction.create,
      source: AnalyticsSource.playlists,
    );
    final id = await ref.read(playlistRepositoryProvider).create(name);
    if (!context.mounted) return;
    // 新建的清單是空的:進詳細頁後直接疊上「增加項目」頁,返回即回到
    // 這個清單(見 PlaylistDetailPage.openAddTracksOnOpen)。
    context.push(
      '/library/playlists/$id?${PlaylistDetailPage.addTracksQuery}=1',
    );
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
    logAnalyticsAction(PlaylistAction.rename);
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
    logAnalyticsAction(PlaylistAction.delete);
    await ref.read(playlistRepositoryProvider).delete(playlist.id);
  }

  /// 曲數副標;沒有曲目時不顯示文字,但仍回傳空 widget 佔住 subtitle
  /// 位置,讓 [ListTile] 一律走雙行版面。列高由 `minTileHeight: 60` 固定,
  /// 有無曲數都等高。
  Widget _countSubtitle(AppLocalizations l10n, int count) => count > 0
      ? Text(l10n.playlist_track_count(count))
      : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        // 分頁根頁沒有返回鍵,左側改放 app 圖示。
        leading: const AppLogoLeading(),
        title: Text(l10n.tab_library),
      ),
      floatingActionButton: FloatingActionButton(
        // 各分頁在 IndexedStack 中同時存在,共用預設 hero tag 會在推頁時
        // 衝突;FAB 不需要 hero 轉場,直接關掉。
        heroTag: null,
        onPressed: () => _create(context, ref),
        tooltip: l10n.playlist_new,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          ?widget.header,
          Expanded(child: _buildList(l10n, playlists)),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n, List<PlaylistEntity> playlists) {
    return playlists.isEmpty
        ? Center(child: Text(l10n.playlists_empty))
        : ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              // 曲數只計 music library 找得到的曲目(來源檔已移除 / 尚未
              // 掃描到的略過),與詳頁實際顯示的清單一致。
              final trackCount = playlist.isRecentlyPlayed
                  ? ref.watch(recentlyPlayedProvider).length
                  : ref.watch(playlistTracksProvider(playlist.id)).length;
              return ListTile(
                minTileHeight: 60,
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
                subtitle: _countSubtitle(l10n, trackCount),
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
                onTap: () => context.push('/library/playlists/${playlist.id}'),
              );
            },
          );
  }
}
