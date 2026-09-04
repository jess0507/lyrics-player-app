import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/core/sync/statistics_backup.dart';
import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/models/period_stat_entity.dart';

DailyTrackStatEntity _day(String day, String trackId, int plays, int ms) =>
    DailyTrackStatEntity()
      ..day = day
      ..trackId = trackId
      ..title = 'T-$trackId'
      ..playCount = plays
      ..listenMs = ms;

PeriodStatEntity _month(String period, int plays, int ms) => PeriodStatEntity()
  ..period = period
  ..playCount = plays
  ..listenMs = ms;

void main() {
  test('按月分桶:同月的每日明細進同一桶,月總量以傳入的 totals 為準', () {
    final json = StatisticsBackup.encodeStatistics(
      [
        _day('2026-08-30', 'a', 1, 100),
        _day('2026-08-30', 'b', 2, 200),
        _day('2026-09-01', 'a', 3, 300),
      ],
      [_month('2026-08', 3, 300), _month('2026-09', 3, 300)],
    );
    final months = json['months'] as Map;
    expect(months.keys, ['2026-08', '2026-09']);
    final aug = months['2026-08'] as Map;
    expect(aug['playCount'], 3);
    expect(aug['listenMs'], 300);
    expect((aug['days'] as Map)['2026-08-30'], {
      'a': {'title': 'T-a', 'playCount': 1, 'listenMs': 100},
      'b': {'title': 'T-b', 'playCount': 2, 'listenMs': 200},
    });
  });

  test('只有月總量沒有明細的月份(歷史截斷)也保留', () {
    final json = StatisticsBackup.encodeStatistics(
      [_day('2026-09-01', 'a', 1, 1)],
      [_month('2025-01', 50, 5000), _month('2026-09', 1, 1)],
    );
    final months = json['months'] as Map;
    expect(months['2025-01'], {'days': {}, 'playCount': 50, 'listenMs': 5000});
  });

  test('encode → JSON → decode round-trip', () {
    final days = [
      _day('2026-08-30', 'a', 1, 100),
      _day('2026-09-01', 'a', 3, 300),
    ];
    final totals = [_month('2026-08', 1, 100), _month('2026-09', 3, 300)];
    final json = jsonDecode(
      jsonEncode(StatisticsBackup.encodeStatistics(days, totals)),
    );

    final decodedDays = StatisticsBackup.decodeDailyStats(json)
      ..sort((x, y) => x.day.compareTo(y.day));
    expect(decodedDays, hasLength(2));
    expect(decodedDays[0].day, '2026-08-30');
    expect(decodedDays[0].trackId, 'a');
    expect(decodedDays[0].title, 'T-a');
    expect(decodedDays[0].playCount, 1);
    expect(decodedDays[0].listenMs, 100);
    expect(decodedDays[1].day, '2026-09-01');

    final decodedTotals = StatisticsBackup.decodeMonthlyTotals(json)
      ..sort((x, y) => x.period.compareTo(y.period));
    expect(decodedTotals.map((m) => m.period), ['2026-08', '2026-09']);
    expect(decodedTotals[1].playCount, 3);
    expect(decodedTotals[1].listenMs, 300);
  });

  test('容錯:缺 title 用 trackId、格式不符的條目跳過、缺 months 回空', () {
    final json = {
      'months': {
        '2026-09': {
          'days': {
            '2026-09-01': {
              'a': {'playCount': 2},
              'b': 'garbage',
            },
            '2026-09-02': 'garbage',
          },
        },
        '2026-10': 'garbage',
      },
    };
    final days = StatisticsBackup.decodeDailyStats(json);
    expect(days, hasLength(1));
    expect(days.single.title, 'a');
    expect(days.single.playCount, 2);
    expect(days.single.listenMs, 0);

    final totals = StatisticsBackup.decodeMonthlyTotals(json);
    expect(totals.single.period, '2026-09');
    expect(totals.single.playCount, 0);

    expect(StatisticsBackup.decodeDailyStats({}), isEmpty);
    expect(StatisticsBackup.decodeMonthlyTotals({}), isEmpty);
  });
}
