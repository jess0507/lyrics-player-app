import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/profile/statistics/providers/chart_selection_provider.dart';
import 'package:seek_player/features/profile/statistics/providers/chart_series_provider.dart';

/// _StatCard 要顯示的時長與次數(由圖表選取導出)。
class SelectedStat {
  const SelectedStat({
    required this.listenTime,
    required this.playCount,
    this.periodLabel,
  });

  final Duration listenTime;
  final int playCount;

  /// 觸碰選中某期間時的顯示標籤(day `M/d`、month `yyyy/M`);
  /// null 表示目前是整個範圍的彙總。
  final String? periodLabel;
}

/// 依圖表選取(範圍 + 觸碰節點)導出 _StatCard 的數值:
/// 未觸碰節點時為整個範圍 series 的彙總,觸碰某期間則取該單點。
final selectedStatProvider = Provider<SelectedStat>((ref) {
  final selection = ref.watch(chartSelectionProvider);
  final points = ref.watch(chartSeriesProvider(selection.range));

  if (selection.touchedPeriod != null) {
    for (final p in points) {
      if (p.period == selection.touchedPeriod) {
        return SelectedStat(
          listenTime: p.listenTime,
          playCount: p.playCount,
          periodLabel: _periodLabel(selection.range, p.period),
        );
      }
    }
  }

  var listenMs = 0;
  var playCount = 0;
  for (final p in points) {
    listenMs += p.listenTime.inMilliseconds;
    playCount += p.playCount;
  }
  return SelectedStat(
    listenTime: Duration(milliseconds: listenMs),
    playCount: playCount,
  );
});

/// 期間 key 轉短標籤:年視圖為 `yyyy/M`(月粒度),其餘為 `M/d`(日粒度)。
String _periodLabel(ChartRange range, String period) {
  final month = int.parse(period.substring(5, 7));
  if (range == ChartRange.year) return '${period.substring(0, 4)}/$month';
  return '$month/${int.parse(period.substring(8))}';
}
