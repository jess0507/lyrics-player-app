import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/playlists/providers/playlists_provider.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';
import 'package:seek_player/features/tools/models/track_play_stat.dart';

/// 每首曲目的播放紀錄(`trackId -> TrackPlayStat`);沒播過的曲目不在結果中。
/// 次數取自聆聽統計,最近播放時間優先取「最近播放」清單(上限 200 首),
/// 超出清單的曲目退回統計的日期。隨統計與清單變動重算。
final trackPlayStatsProvider = Provider<Map<String, TrackPlayStat>>((ref) {
  final days = ref.watch(statisticsControllerProvider).days;
  final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
  final recent = playlists.where((p) => p.isRecentlyPlayed).firstOrNull;

  final counts = <String, int>{};
  final lastDays = <String, String>{};
  for (final d in days) {
    if (d.playCount <= 0) continue;
    counts[d.trackId] = (counts[d.trackId] ?? 0) + d.playCount;
    // days 依日期升冪,後出現的即較新。
    lastDays[d.trackId] = d.day;
  }
  final playedAt = {
    for (final e in recent?.recentlyPlayed ?? const []) e.trackId: e.playedAt,
  };

  return {
    for (final id in {...counts.keys, ...playedAt.keys})
      id: TrackPlayStat(
        playCount: counts[id] ?? 0,
        lastPlayed:
            playedAt[id] ??
            (lastDays[id] == null ? null : DateTime.parse(lastDays[id]!)),
      ),
  };
});
