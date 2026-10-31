import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/tools/models/track_file_stat.dart';
import 'package:seek_player/features/tools/models/track_play_stat.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具選曲頁的排序欄位。
enum TrackSortField {
  timeAdded,
  name,
  duration,
  size,
  playCount,
  lastPlayed;

  String label(AppLocalizations l10n) => switch (this) {
    timeAdded => l10n.tools_sort_time_added,
    name => l10n.tools_sort_name,
    duration => l10n.tools_sort_duration,
    size => l10n.tools_sort_size,
    playCount => l10n.tools_sort_play_count,
    lastPlayed => l10n.tools_sort_last_played,
  };

  /// 依欄位語意給「遞減 / 遞增」的顯示文字(例如時間是新到舊、名稱是 Z 到 A)。
  String orderLabel(AppLocalizations l10n, {required bool descending}) =>
      switch (this) {
        timeAdded || lastPlayed =>
          descending ? l10n.tools_sort_new_to_old : l10n.tools_sort_old_to_new,
        name => descending ? l10n.tools_sort_z_to_a : l10n.tools_sort_a_to_z,
        duration || size =>
          descending
              ? l10n.tools_sort_large_to_small
              : l10n.tools_sort_small_to_large,
        playCount =>
          descending
              ? l10n.tools_sort_most_to_least
              : l10n.tools_sort_least_to_most,
      };
}

/// 排序設定:欄位 + 方向。預設依加入時間由新到舊。
class TrackSort {
  const TrackSort({
    this.field = TrackSortField.timeAdded,
    this.descending = true,
  });

  final TrackSortField field;
  final bool descending;

  /// 回傳排序後的新清單;缺 stat / 時長 / 播放紀錄的曲目視為最小值。
  List<Track> apply(
    List<Track> tracks,
    Map<String, TrackFileStat> stats,
    Map<String, TrackPlayStat> plays,
  ) {
    int compare(Track a, Track b) => switch (field) {
      TrackSortField.timeAdded =>
        (stats[a.filePath]?.modified.millisecondsSinceEpoch ?? 0).compareTo(
          stats[b.filePath]?.modified.millisecondsSinceEpoch ?? 0,
        ),
      TrackSortField.name => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      TrackSortField.duration => (a.durationMs ?? 0).compareTo(
        b.durationMs ?? 0,
      ),
      TrackSortField.size => (stats[a.filePath]?.sizeBytes ?? 0).compareTo(
        stats[b.filePath]?.sizeBytes ?? 0,
      ),
      TrackSortField.playCount => (plays[a.id]?.playCount ?? 0).compareTo(
        plays[b.id]?.playCount ?? 0,
      ),
      TrackSortField.lastPlayed =>
        (plays[a.id]?.lastPlayed?.millisecondsSinceEpoch ?? 0).compareTo(
          plays[b.id]?.lastPlayed?.millisecondsSinceEpoch ?? 0,
        ),
    };
    return [...tracks]
      ..sort((a, b) => descending ? compare(b, a) : compare(a, b));
  }
}
