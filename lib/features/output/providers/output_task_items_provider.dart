import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/output/models/output_task_item.dart';

/// 「Output → 任務」:已送出、尚未回終態的歌詞任務(AI 產生 / 對時),
/// 來源為本機待同步清單,依送出順序排列。對不到音樂庫的任務略過。
final outputTaskItemsProvider = Provider<List<OutputTaskItem>>((ref) {
  final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
  final jobs = ref.watch(lyricsPendingSyncStoreProvider);
  final byId = {for (final t in tracks) t.trackId: t};
  return [
    for (final MapEntry(key: trackId, value: job) in jobs.entries)
      if (byId[trackId] case final track?)
        OutputTaskItem(track: track, job: job),
  ];
});
