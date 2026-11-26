import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';
import 'package:seek_player/features/music_list/models/track.dart';

/// 「Output → 任務」的一列:進行中的歌詞任務與其曲目。
class OutputTaskItem {
  const OutputTaskItem({required this.track, required this.job});

  final Track track;
  final LyricsPendingSyncJob job;
}
