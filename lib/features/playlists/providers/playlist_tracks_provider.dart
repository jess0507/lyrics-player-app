import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';

/// 依 playlist id 把有序 trackId 解析成 [Track](回 music library 對齊)。
/// 來源檔已被移除 / 尚未掃描到的曲目會被略過,保留原順序。隨清單與音樂庫變動。
final playlistTracksProvider = Provider.family<List<Track>, int>((ref, id) {
  final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
  final playlist = playlists.where((p) => p.id == id).firstOrNull;
  if (playlist == null) return const [];

  final library = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
  final byId = {for (final t in library) t.id: t};
  return [
    for (final trackId in playlist.trackIds)
      if (byId[trackId] != null) byId[trackId]!,
  ];
});
