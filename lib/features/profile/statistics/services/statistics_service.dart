import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/models/period_stat_entity.dart';

/// 聆聽統計：由 Isar 的每日 × 每首歌記錄導出的 view。
///
/// 不存任何總和——累計總量、排行、每日總量皆於讀取時由 [days] 聚合導出，
/// 本機與雲端結構對稱，不會有「總計與明細對不上」的問題。
class StatisticsData {
  const StatisticsData(this.days);

  /// 每日 × 每首歌的記錄（依日期升冪）。
  final List<DailyTrackStatEntity> days;

  int get totalPlayCount => days.fold(0, (sum, d) => sum + d.playCount);

  int get totalListenMs => days.fold(0, (sum, d) => sum + d.listenMs);

  Duration get totalListenTime => Duration(milliseconds: totalListenMs);

  /// 某一天（本地日期）的統計子集：導出 getter 全部只算該日。
  StatisticsData onDay(DateTime date) =>
      _matching(StatisticsController.dayKey(date));

  /// 某一月的統計子集。
  StatisticsData inMonth(DateTime date) =>
      _matching('${StatisticsController.monthKey(date)}-');

  /// 某一年的統計子集。
  StatisticsData inYear(DateTime date) =>
      _matching('${StatisticsController.yearKey(date)}-');

  /// 期間內聽過的所有歌與各自的次數、時長（title 聚合，依次數排序）。
  ///
  /// 以 title 聚合：從雲端還原的記錄帶舊裝置的 trackId，同一首歌在新裝置
  /// 播放會另起一筆，聚合後才不會同曲分裂成兩列。
  List<TrackRanking> allTracks() => _aggregateByTitle(days);

  /// 依播放次數排序的前幾名（跨日加總；標題、次數、聆聽時長）。
  List<TrackRanking> topTracks([int limit = 5]) =>
      allTracks().take(limit).toList();

  /// 每日總量（依日期升冪），供時間軸圖表使用；
  /// 缺日（沒聽歌的天）不產生條目，由顯示層補零。
  List<DailyTotal> dailyTotals() {
    final byDay = <String, ({int playCount, int listenMs})>{};
    for (final d in days) {
      final prev = byDay[d.day] ?? (playCount: 0, listenMs: 0);
      byDay[d.day] = (
        playCount: prev.playCount + d.playCount,
        listenMs: prev.listenMs + d.listenMs,
      );
    }
    final keys = byDay.keys.toList()..sort();
    return [
      for (final day in keys)
        DailyTotal(
          day: day,
          playCount: byDay[day]!.playCount,
          listenTime: Duration(milliseconds: byDay[day]!.listenMs),
        ),
    ];
  }

  /// day key 為定長 `yyyy-MM-dd`，prefix 比對即可取日（完整 key）／月／年。
  StatisticsData _matching(String prefix) => StatisticsData([
    for (final d in days)
      if (d.day.startsWith(prefix)) d,
  ]);

  static List<TrackRanking> _aggregateByTitle(
    Iterable<DailyTrackStatEntity> records,
  ) {
    final byTitle = <String, ({int playCount, int listenMs})>{};
    for (final r in records) {
      final prev = byTitle[r.title] ?? (playCount: 0, listenMs: 0);
      byTitle[r.title] = (
        playCount: prev.playCount + r.playCount,
        listenMs: prev.listenMs + r.listenMs,
      );
    }
    return [
      for (final e in byTitle.entries)
        TrackRanking(
          title: e.key,
          playCount: e.value.playCount,
          listenTime: Duration(milliseconds: e.value.listenMs),
        ),
    ]..sort((a, b) => b.playCount.compareTo(a.playCount));
  }
}

/// 排行榜單一列：同 title 聚合後的次數與聆聽時長。
class TrackRanking {
  const TrackRanking({
    required this.title,
    required this.playCount,
    required this.listenTime,
  });

  final String title;
  final int playCount;
  final Duration listenTime;
}

/// 單日聚合總量（時間軸圖表的一個資料點）。
class DailyTotal {
  const DailyTotal({
    required this.day,
    required this.playCount,
    required this.listenTime,
  });

  /// 本地日期 `yyyy-MM-dd`。
  final String day;
  final int playCount;
  final Duration listenTime;
}

class StatisticsController extends Notifier<StatisticsData> {
  Isar get _isar => ref.read(isarProvider);
  IsarCollection<DailyTrackStatEntity> get _days => _isar.dailyTrackStatEntitys;
  IsarCollection<PeriodStatEntity> get _periods => _isar.periodStatEntitys;

  @override
  StatisticsData build() {
    return _load();
  }

  StatisticsData _load() =>
      StatisticsData(_days.where().sortByDay().findAllSync());

  /// 一首曲目開始播放時呼叫。
  void recordPlay(Track track) => _record(track, playCount: 1);

  /// 累加該曲目當日的聆聽時長（播放期間定期取樣）。
  void addListenTime(Track track, Duration duration) {
    if (duration <= Duration.zero) return;
    _record(track, listenMs: duration.inMilliseconds);
  }

  /// 同一個交易內 upsert 兩筆：每曲明細（今天, trackId）與本月 month total
  /// ——明細與月總量必成對，不會出現只寫一半的狀態。
  /// day total 不另存：day 數據就是明細本身，週/月視圖直接由明細聚合。
  void _record(Track track, {int playCount = 0, int listenMs = 0}) {
    final now = DateTime.now();
    final today = dayKey(now);
    late DailyTrackStatEntity entity;
    _isar.writeTxnSync(() {
      entity =
          (_days.getByDayTrackIdSync(today, track.id) ??
                (DailyTrackStatEntity()
                  ..day = today
                  ..trackId = track.id))
            ..title = track.title
            ..playCount += playCount
            ..listenMs += listenMs;
      _days.putSync(entity);
      _bumpMonthSync(monthKey(now), playCount, listenMs);
    });
    _commit(entity);
  }

  /// 累加指定月份 total（須在 writeTxnSync 內呼叫）。
  void _bumpMonthSync(String period, int playCount, int listenMs) {
    final entity =
        _periods.getByPeriodSync(period) ??
        (PeriodStatEntity()..period = period);
    _periods.putSync(
      entity
        ..playCount += playCount
        ..listenMs += listenMs,
    );
  }

  /// 月粒度 totals（依 period 升冪），供同步上傳（`monthlyTotals` 子集合，
  /// 見 StatisticsSync）。
  List<PeriodStatEntity> monthlyTotals() =>
      _periods.where().sortByPeriod().findAllSync();

  /// 定向重算：只重算指定日所屬的 month bucket（明細索引範圍查詢聚合後
  /// upsert 覆寫）。用於「已知哪幾天的明細被批次改動」的場合。
  void recomputePeriods(Iterable<String> dayKeys) {
    final months = {for (final d in dayKeys) d.substring(0, 7)};
    _isar.writeTxnSync(() {
      for (final month in months) {
        _putComputedMonthSync(
          month,
          _days.filter().dayStartsWith('$month-').findAllSync(),
        );
      }
    });
  }

  /// 以明細聚合結果覆寫單一月份 total（須在 writeTxnSync 內呼叫）。
  void _putComputedMonthSync(
    String period,
    List<DailyTrackStatEntity> records,
  ) {
    var playCount = 0;
    var listenMs = 0;
    for (final r in records) {
      playCount += r.playCount;
      listenMs += r.listenMs;
    }
    final entity =
        _periods.getByPeriodSync(period) ??
        (PeriodStatEntity()..period = period);
    _periods.putSync(
      entity
        ..playCount = playCount
        ..listenMs = listenMs,
    );
  }

  /// 清空本機統計（明細與期間 totals 同交易清空）。
  /// 雲端備份的刪除由呼叫端透過 SyncService 處理。
  void reset() {
    _isar.writeTxnSync(() {
      _days.clearSync();
      _periods.clearSync();
    });
    state = const StatisticsData([]);
    ref.read(syncStateStoreProvider).markStatsModified();
  }

  /// 還原雲端備份（整份覆寫本機）。
  ///
  /// [monthlyTotals] 為雲端 `monthlyTotals` 子集合的月粒度 totals——月粒度
  /// 以雲端為準（將來明細被截斷後，月總量只有雲端是完整的）；未提供時
  /// （例：本機測試、雲端子集合缺漏）由明細單趟重建月總量。
  /// day 數據即明細本身，隨 [entities] 一併落地，兩種情形都不需另外重建。
  ///
  /// 還原不算本機變更：不更新 lastModifiedAt，避免還原後馬上又觸發上傳。
  void restoreFromRemote(
    List<DailyTrackStatEntity> entities, {
    List<PeriodStatEntity>? monthlyTotals,
  }) {
    final months = monthlyTotals ?? _aggregateMonthTotals(entities);
    _isar.writeTxnSync(() {
      _days.clearSync();
      _days.putAllSync(entities);
      _periods.clearSync();
      _periods.putAllSync(months);
    });
    state = _load();
  }

  /// 由明細在記憶體單趟聚合出月粒度 totals（v2 還原重建用）。
  static List<PeriodStatEntity> _aggregateMonthTotals(
    Iterable<DailyTrackStatEntity> records,
  ) {
    final byMonth = <String, ({int playCount, int listenMs})>{};
    for (final r in records) {
      final month = r.day.substring(0, 7);
      final prev = byMonth[month] ?? (playCount: 0, listenMs: 0);
      byMonth[month] = (
        playCount: prev.playCount + r.playCount,
        listenMs: prev.listenMs + r.listenMs,
      );
    }
    return [
      for (final e in byMonth.entries)
        PeriodStatEntity()
          ..period = e.key
          ..playCount = e.value.playCount
          ..listenMs = e.value.listenMs,
    ];
  }

  /// 本地日期轉 `yyyy-MM-dd` key。
  static String dayKey(DateTime t) => '${monthKey(t)}-${_pad(t.day)}';

  /// 本地日期轉 `yyyy-MM` key。
  static String monthKey(DateTime t) => '${yearKey(t)}-${_pad(t.month)}';

  /// 本地日期轉 `yyyy` key。
  static String yearKey(DateTime t) => t.year.toString().padLeft(4, '0');

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// 寫入後把單筆 upsert 增量套進 state，不全量重讀
  /// （addListenTime 每 5 秒取樣一次，資料量大時全量重讀划不來）。
  void _commit(DailyTrackStatEntity entity) {
    final days = [...state.days];
    final i = days.indexWhere(
      (d) => d.day == entity.day && d.trackId == entity.trackId,
    );
    if (i >= 0) {
      days[i] = entity;
    } else {
      days.add(entity); // 新記錄必為今天，接在升冪清單尾端即仍有序
    }
    state = StatisticsData(days);
    ref.read(syncStateStoreProvider).markStatsModified();
  }
}

final statisticsControllerProvider =
    NotifierProvider<StatisticsController, StatisticsData>(
      StatisticsController.new,
    );
