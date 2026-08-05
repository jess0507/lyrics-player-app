import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

/// 系統清單排序優先度:我的最愛最前,最近播放次之,其餘使用者清單最後
/// (依建立時間由舊到新)。
int _sortTier(PlaylistEntity p) {
  if (p.isFavorites) return 0;
  if (p.isRecentlyPlayed) return 1;
  return 2;
}

/// 所有播放清單,排序為:我的最愛、最近播放固定在最前,其餘依建立時間
/// 由舊到新。
final playlistsProvider = StreamProvider<List<PlaylistEntity>>((ref) {
  final repo = ref.watch(playlistRepositoryProvider);
  return repo.watchAll().map((list) {
    final sorted = [...list]
      ..sort((a, b) {
        final tierDiff = _sortTier(a) - _sortTier(b);
        if (tierDiff != 0) return tierDiff;
        return a.createdAt.compareTo(b.createdAt);
      });
    return sorted;
  });
});
