import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「編輯播放清單」頁排序右側的全部移除鈕:確認後移除目前篩選 / 搜尋出的
/// [tracks]。
class PlaylistRemoveAllButton extends ConsumerWidget {
  const PlaylistRemoveAllButton({
    super.key,
    required this.playlistId,
    required this.tracks,
    required this.analyticsSource,
  });

  final int playlistId;
  final List<Track> tracks;
  final AnalyticsSource analyticsSource;

  Future<void> _confirmRemoveAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playlist_remove_all),
        content: Text(l10n.playlist_remove_all_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    logAnalyticsAction(PlaylistAction.removeAllTracks, source: analyticsSource);
    await ref.read(playlistRepositoryProvider).removeTracks(playlistId, {
      for (final t in tracks) t.trackId,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: l10n.playlist_remove_all,
      icon: const Icon(Icons.delete_sweep_outlined),
      onPressed: tracks.isEmpty ? null : () => _confirmRemoveAll(context, ref),
    );
  }
}
