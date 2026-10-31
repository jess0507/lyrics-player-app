import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/playlists/models/track_folder.dart';

/// 曲目檔案的 stat 資訊,供工具選曲頁顯示大小與排序。
class TrackFileStat {
  const TrackFileStat({required this.sizeBytes, required this.modified});

  final int sizeBytes;

  /// 檔案最後修改時間;Track 不帶 MediaStore 的加入時間,以此近似「加入時間」。
  final DateTime modified;
}

/// [tracks] 中位於 [folderPath](null 為全部)的最新檔案修改時間;未知回 null。
/// 供資料夾下拉顯示各資料夾的最新日期。
DateTime? latestModifiedIn(
  Iterable<Track> tracks,
  Map<String, TrackFileStat> stats,
  String? folderPath,
) {
  DateTime? latest;
  for (final t in tracks) {
    if (folderPath != null && TrackFolder.dirOf(t.filePath) != folderPath) {
      continue;
    }
    final modified = stats[t.filePath]?.modified;
    if (modified != null && (latest == null || modified.isAfter(latest))) {
      latest = modified;
    }
  }
  return latest;
}
