import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../music_list/providers/music_library.dart';
import '../../music_list/models/track.dart';
import 'playlists_provider.dart';

/// 一筆已解析的最近播放紀錄:曲目 + 播放當下時間。
class RecentlyPlayedItem {
  const RecentlyPlayedItem({required this.track, required this.playedAt});

  final Track track;
  final DateTime playedAt;
}

/// 「最近播放」清單,依播放時間新到舊排序(來源已是此順序,見
/// [PlaylistRepository.recordRecentlyPlayed])。來源檔已被移除 / 尚未掃描到
/// 的曲目會被略過。隨清單與音樂庫變動。
final recentlyPlayedProvider = Provider<List<RecentlyPlayedItem>>((ref) {
  final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
  final playlist = playlists.where((p) => p.isRecentlyPlayed).firstOrNull;
  if (playlist == null) return const [];

  final library = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
  final byId = {for (final t in library) t.id: t};
  return [
    for (final entry in playlist.recentlyPlayed)
      if (byId[entry.trackId] case final track?)
        RecentlyPlayedItem(track: track, playedAt: entry.playedAt),
  ];
});
