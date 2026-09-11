import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/models/period_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';

/// 播放統計與 `user/{uid}/monthlyStats` 子集合的推送與還原(SyncService
/// 調度)。逐月一份文件(docId 為 `yyyy-MM`),同時存當月逐日明細(`days`)
/// 與月粒度加總(`playCount` / `listenMs`);月份分桶避免單一文件撞
/// 1 MiB 上限,也讓寫入次數不隨歷史天數無上限成長。
class StatisticsSync {
  StatisticsSync(this._ref);

  final Ref _ref;

  /// 讀一次統計 provider,確保 prefs -> Isar 遷移已執行
  /// (遷移視為本機變更,會更新 statsModifiedAt)。上傳判斷前呼叫。
  void ensureMigrated() => _ref.read(statisticsControllerProvider);

  /// 全量推送 [userDoc] 的 `monthlyStats` 子集合:先刪本機沒有的雲端月份
  /// 文件,再整批重寫本機所有月份。完整快照語意(不合併、不加總)。
  Future<void> push(DocumentReference<Map<String, dynamic>> userDoc) async {
    final days = _ref.read(statisticsControllerProvider).days;
    final months = _ref
        .read(statisticsControllerProvider.notifier)
        .monthlyTotals();

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

    final monthKeys = {...dailyByMonth.keys, ...totalsByMonth.keys};
    final col = userDoc.collection('monthlyStats');
    final cloudMonthIds = (await col.get()).docs.map((d) => d.id).toSet();

    final firestore = userDoc.firestore;
    var batch = firestore.batch();
    var pendingOps = 0;
    Future<void> addOp(void Function(WriteBatch b) op) async {
      op(batch);
      // WriteBatch 上限 500 個操作,分批送出。
      if (++pendingOps < 400) return;
      await batch.commit();
      batch = firestore.batch();
      pendingOps = 0;
    }

    for (final stale in cloudMonthIds.difference(monthKeys)) {
      await addOp((b) => b.delete(col.doc(stale)));
    }
    for (final month in monthKeys) {
      final total = totalsByMonth[month];
      await addOp(
        (b) => b.set(col.doc(month), {
          'days': dailyByMonth[month] ?? const {},
          'playCount': total?.playCount ?? 0,
          'listenMs': total?.listenMs ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    }
    if (pendingOps > 0) await batch.commit();
  }

  /// 以 [userDoc] 的 `monthlyStats` 子集合整份覆寫本機統計(空集合也覆寫)。
  Future<void> restore(DocumentReference<Map<String, dynamic>> userDoc) async {
    final snapshot = await userDoc.collection('monthlyStats').get();
    _ref
        .read(statisticsControllerProvider.notifier)
        .restoreFromRemote(
          snapshot.toDailyTrackStats(),
          monthlyTotals: snapshot.toMonthlyTotals(),
        );
  }
}

final statisticsSyncProvider = Provider<StatisticsSync>(
  (ref) => StatisticsSync(ref),
);

/// 雲端 `monthlyStats` 子集合快照 -> 每日記錄的解碼(`days` 欄位),
/// 容錯:缺欄位給預設值、格式不符的條目跳過。
extension _RemoteDailyStatsDecode on QuerySnapshot<Map<String, dynamic>> {
  List<DailyTrackStatEntity> toDailyTrackStats() {
    final entities = <DailyTrackStatEntity>[];
    for (final doc in docs) {
      final days = doc.data()['days'];
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
}

/// 雲端 `monthlyStats` 子集合快照 -> 月粒度 totals 的解碼
/// (`playCount` / `listenMs` 欄位,文件 id 即 period)。
extension _RemoteMonthlyTotalsDecode on QuerySnapshot<Map<String, dynamic>> {
  List<PeriodStatEntity> toMonthlyTotals() {
    final entities = <PeriodStatEntity>[];
    for (final doc in docs) {
      final data = doc.data();
      entities.add(
        PeriodStatEntity()
          ..period = doc.id
          ..playCount = (data['playCount'] as num? ?? 0).toInt()
          ..listenMs = (data['listenMs'] as num? ?? 0).toInt(),
      );
    }
    return entities;
  }
}
