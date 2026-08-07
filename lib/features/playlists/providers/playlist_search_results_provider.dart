import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';

import 'package:seek_player/features/playlists/providers/playlist_search_query_provider.dart';
import 'package:seek_player/features/playlists/providers/playlist_tracks_provider.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/playlists/providers/recently_played_provider.dart';

/// 依關鍵字過濾指定播放清單內曲目的搜尋結果（未輸入關鍵字時回空清單）。
/// [playlistId] 為 null 代表「本地音樂」虛擬清單,搜尋範圍是整個音樂庫。
final playlistSearchResultsProvider =
    Provider.autoDispose.family<List<Track>, int?>((ref, playlistId) {
      final query = ref.watch(playlistSearchQueryProvider).trim().toLowerCase();
      if (query.isEmpty) return const [];
      final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
      final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
      // 「最近播放」的曲目存在 recentlyPlayed 紀錄而非 trackIds,來源不同。
      final tracks = playlistId == null
          ? ref.watch(musicLibraryProvider).valueOrNull ?? const <Track>[]
          : (playlist?.isRecentlyPlayed ?? false)
          ? [for (final item in ref.watch(recentlyPlayedProvider)) item.track]
          : ref.watch(playlistTracksProvider(playlistId));
      return tracks.where((t) {
        return t.title.toLowerCase().contains(query) ||
            (t.artist?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
