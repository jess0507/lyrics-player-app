import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/models/track.dart';

import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/providers/music_search_query_provider.dart';

/// 套用搜尋過濾後的曲目清單（掃描中／失敗時回空清單）。
final filteredTracksProvider = Provider<List<Track>>((ref) {
  final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
  final query = ref.watch(musicSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return tracks;
  return tracks.where((t) {
    return t.title.toLowerCase().contains(query) ||
        (t.artist?.toLowerCase().contains(query) ?? false);
  }).toList();
});
