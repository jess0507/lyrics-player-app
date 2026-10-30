import 'package:seek_player/features/music_list/models/track.dart';

/// 依 [Track.filePath] 所在目錄分組出的資料夾,供本地音樂快速篩選。
class TrackFolder {
  const TrackFolder({
    required this.path,
    required this.name,
    required this.trackCount,
  });

  /// 目錄完整路徑,作為篩選的識別鍵(不同位置的同名資料夾各自獨立)。
  final String path;

  /// 顯示用名稱:目錄的最後一段。
  final String name;

  final int trackCount;

  /// 取檔案路徑的上層目錄;沒有分隔符時回傳空字串。
  static String dirOf(String filePath) {
    final i = filePath.lastIndexOf('/');
    return i <= 0 ? '' : filePath.substring(0, i);
  }

  /// 將曲目依所在目錄分組,依名稱(不分大小寫)排序。
  static List<TrackFolder> groupTracks(List<Track> tracks) {
    final counts = <String, int>{};
    for (final track in tracks) {
      final dir = dirOf(track.filePath);
      counts[dir] = (counts[dir] ?? 0) + 1;
    }
    final folders = [
      for (final entry in counts.entries)
        TrackFolder(
          path: entry.key,
          name: entry.key.isEmpty
              ? '/'
              : entry.key.substring(entry.key.lastIndexOf('/') + 1),
          trackCount: entry.value,
        ),
    ];
    folders.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.path.compareTo(b.path);
    });
    return folders;
  }
}
