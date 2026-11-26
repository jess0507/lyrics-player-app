import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 本機全部有內容的歌詞(Isar 即時監聽);AI 產生任務的空內容佔位不算。
final lyricsEntitiesProvider = StreamProvider<List<LyricsEntity>>(
  (ref) => ref.watch(lyricsRepositoryProvider).watchAllWithContent(),
);
