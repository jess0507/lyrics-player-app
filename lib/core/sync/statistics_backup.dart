import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/domain_backup.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';
import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/models/period_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';

/// 播放統計 ↔ `statistics.json`:
/// `{ "months": { "yyyy-MM": { "days": { "yyyy-MM-dd": { trackId: {title,
/// playCount, listenMs} } }, "playCount", "listenMs" } } }`。
/// 按月分桶只是沿用既有 `monthlyTotals()` 的結構(月粒度以雲端為準,
/// 見 StatisticsController.restoreFromRemote)。
class StatisticsBackup implements DomainBackup {
  StatisticsBackup(this._ref);

  final Ref _ref;

  @override
  String get fileName => 'statistics.json';

  @override
  String get label => 'statistics';

  @override
  DateTime? get localModifiedAt =>
      _ref.read(syncStateStoreProvider).statsModifiedAt;

  @override
  Map<String, dynamic> encode() => encodeStatistics(
    _ref.read(statisticsControllerProvider).days,
    _ref.read(statisticsControllerProvider.notifier).monthlyTotals(),
  );

  @override
  Future<void> restore(Map<String, dynamic> json) async {
    _ref
        .read(statisticsControllerProvider.notifier)
        .restoreFromRemote(
          decodeDailyStats(json),
          monthlyTotals: decodeMonthlyTotals(json),
        );
  }

  /// 純函式,供測試 round-trip。
  static Map<String, dynamic> encodeStatistics(
    List<DailyTrackStatEntity> days,
    List<PeriodStatEntity> months,
  ) {
    final dailyByMonth = <String, Map<String, Map<String, Object>>>{};
    for (final d in days) {
      final month = d.day.substring(0, 7);
      ((dailyByMonth[month] ??= {})[d.day] ??= {})[d.trackId] = {
        'title': d.title,
        'playCount': d.playCount,
        'listenMs': d.listenMs,
      };
    }
    final totalsByMonth = {for (final m in months) m.period: m};
    final monthKeys = {...dailyByMonth.keys, ...totalsByMonth.keys}.toList()
      ..sort();
    return {
      'months': {
        for (final month in monthKeys)
          month: {
            'days': dailyByMonth[month] ?? const <String, Object>{},
            'playCount': totalsByMonth[month]?.playCount ?? 0,
            'listenMs': totalsByMonth[month]?.listenMs ?? 0,
          },
      },
    };
  }

  /// `months.*.days` -> 每日記錄;格式不符的條目跳過。
  static List<DailyTrackStatEntity> decodeDailyStats(
    Map<String, dynamic> json,
  ) {
    final entities = <DailyTrackStatEntity>[];
    final months = json['months'];
    if (months is! Map) return entities;
    for (final month in months.values) {
      if (month is! Map) continue;
      final days = month['days'];
      if (days is! Map) continue;
      days.forEach((day, tracks) {
        if (tracks is! Map) return;
        tracks.forEach((trackId, value) {
          if (value is! Map) return;
          entities.add(
            DailyTrackStatEntity()
              ..day = '$day'
              ..trackId = '$trackId'
              ..title = (value['title'] as String?) ?? '$trackId'
              ..playCount = (value['playCount'] as num? ?? 0).toInt()
              ..listenMs = (value['listenMs'] as num? ?? 0).toInt(),
          );
        });
      });
    }
    return entities;
  }

  /// `months.*.{playCount,listenMs}` -> 月粒度 totals(key 即 period)。
  static List<PeriodStatEntity> decodeMonthlyTotals(Map<String, dynamic> json) {
    final entities = <PeriodStatEntity>[];
    final months = json['months'];
    if (months is! Map) return entities;
    months.forEach((period, value) {
      if (value is! Map) return;
      entities.add(
        PeriodStatEntity()
          ..period = '$period'
          ..playCount = (value['playCount'] as num? ?? 0).toInt()
          ..listenMs = (value['listenMs'] as num? ?? 0).toInt(),
      );
    });
    return entities;
  }
}

final statisticsBackupProvider = Provider<StatisticsBackup>(
  (ref) => StatisticsBackup(ref),
);
