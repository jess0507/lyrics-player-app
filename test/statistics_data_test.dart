import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';

DailyTrackStatEntity _stat(
  String day,
  String trackId,
  String title,
  int playCount, [
  int listenMs = 0,
]) {
  return DailyTrackStatEntity()
    ..day = day
    ..trackId = trackId
    ..title = title
    ..playCount = playCount
    ..listenMs = listenMs;
}

void main() {
  test('總計由每日記錄加總導出', () {
    final data = StatisticsData([
      _stat('2026-06-11', '1', 'A', 3, 1000),
      _stat('2026-06-12', '1', 'A', 1, 200),
      _stat('2026-06-12', '2', 'B', 2, 500),
    ]);
    expect(data.totalPlayCount, 6);
    expect(data.totalListenMs, 1700);
    expect(data.totalListenTime, const Duration(milliseconds: 1700));
  });

  test('topTracks 跨日加總並以 title 聚合（吸收跨機 trackId 不一致）', () {
    final data = StatisticsData([
      _stat('2026-06-11', '1', 'Same Song', 3, 1000), // 舊裝置還原的記錄
      _stat('2026-06-12', '900', 'Same Song', 2, 500), // 新裝置另起的 entry
      _stat('2026-06-12', '2', 'Other', 4, 2000),
    ]);
    final top = data.topTracks();
    expect(top.length, 2);
    expect(top[0].title, 'Other');
    expect(top[0].playCount, 4);
    expect(top[0].listenTime, const Duration(milliseconds: 2000));
    expect(top[1].title, 'Same Song');
    expect(top[1].playCount, 5);
    expect(top[1].listenTime, const Duration(milliseconds: 1500));
  });

  test('topTracks 依聆聽時長排序並截斷至 limit', () {
    final data = StatisticsData([
      for (var i = 0; i < 10; i++) _stat('2026-06-12', '$i', 'T$i', i, i * 100),
    ]);
    final top = data.topTracks(3);
    expect(top.map((e) => e.listenTime.inMilliseconds), [900, 800, 700]);
  });

  test('onDay 取當日子集，allTracks 列出當日歌曲與各自次數、時長', () {
    final data = StatisticsData([
      _stat('2026-06-11', '1', 'A', 5, 9000),
      _stat('2026-06-12', '1', 'A', 1, 200),
      _stat('2026-06-12', '2', 'B', 2, 500),
    ]);
    final tracks = data.onDay(DateTime(2026, 6, 12)).allTracks();
    expect(tracks.length, 2);
    expect(tracks[0].title, 'B');
    expect(tracks[0].playCount, 2);
    expect(tracks[0].listenTime, const Duration(milliseconds: 500));
    expect(tracks[1].title, 'A');
    expect(tracks[1].playCount, 1);
    expect(data.onDay(DateTime(2026, 6, 10)).days, isEmpty);
  });

  test('inMonth / inYear 取期間子集，導出 getter 只算該期間', () {
    final data = StatisticsData([
      _stat('2025-12-31', '1', 'A', 1, 100),
      _stat('2026-06-11', '1', 'A', 3, 1000),
      _stat('2026-07-01', '2', 'B', 2, 500),
    ]);
    expect(data.inMonth(DateTime(2026, 6, 15)).totalPlayCount, 3);
    expect(data.inYear(DateTime(2026, 1, 1)).totalPlayCount, 5);
    expect(data.inYear(DateTime(2025, 1, 1)).totalListenMs, 100);
    expect(data.inMonth(DateTime(2026, 5, 1)).days, isEmpty);
  });

  test('dailyTotals 依日聚合並按日期升冪', () {
    final data = StatisticsData([
      _stat('2026-06-12', '1', 'A', 1, 200),
      _stat('2026-06-11', '1', 'A', 3, 1000),
      _stat('2026-06-12', '2', 'B', 2, 500),
    ]);
    final totals = data.dailyTotals();
    expect(totals.map((e) => e.day), ['2026-06-11', '2026-06-12']);
    expect(totals[0].playCount, 3);
    expect(totals[1].playCount, 3);
    expect(totals[1].listenTime, const Duration(milliseconds: 700));
  });

  test('空記錄為零統計', () {
    const data = StatisticsData([]);
    expect(data.totalPlayCount, 0);
    expect(data.totalListenMs, 0);
    expect(data.topTracks(), isEmpty);
    expect(data.dailyTotals(), isEmpty);
  });

  test('day / month / year key 補零格式', () {
    expect(StatisticsController.dayKey(DateTime(2026, 6, 1)), '2026-06-01');
    expect(StatisticsController.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    expect(StatisticsController.monthKey(DateTime(2026, 6, 1)), '2026-06');
    expect(StatisticsController.yearKey(DateTime(2026, 6, 1)), '2026');
  });
}
