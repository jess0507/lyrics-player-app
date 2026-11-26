import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/output/providers/lyrics_entities_provider.dart';

/// 「Output → 歌詞」:音樂庫中有歌詞的曲目,依歌詞加入時間新到舊。
/// 歌詞對不到音樂庫(來源檔已移除 / 尚未掃描到)的略過。
final outputLyricsTracksProvider = Provider<List<Track>>((ref) {
  final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
  final lyrics = ref.watch(lyricsEntitiesProvider).valueOrNull ?? const [];
  final byId = {for (final t in tracks) t.trackId: t};
  final sorted = [...lyrics]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return [for (final entity in sorted) ?byId[entity.trackId]];
});
