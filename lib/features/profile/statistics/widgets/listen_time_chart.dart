import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/format.dart';
import 'package:seek_player/features/profile/statistics/providers/chart_selection_provider.dart';
import 'package:seek_player/features/profile/statistics/providers/chart_series_provider.dart';

/// 聆聽時長折線圖卡片:標題 + 週/月/年視圖切換 + LineChart。
///
/// 資料來自 [chartSeriesProvider](已補零、依時間升冪的期間總量),
/// 縱軸取 listenMs(分鐘),全程不碰每曲明細。
/// 視圖範圍與觸碰選取存於 [chartSelectionProvider],供 _StatCard 連動。
class ListenTimeChart extends ConsumerWidget {
  const ListenTimeChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final range = ref.watch(chartSelectionProvider.select((s) => s.range));
    final points = ref.watch(chartSeriesProvider(range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statistics_chart_title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ChartRange>(
          segments: [
            ButtonSegment(
              value: ChartRange.week,
              label: Text(l10n.statistics_chart_week),
            ),
            ButtonSegment(
              value: ChartRange.month,
              label: Text(l10n.statistics_chart_month),
            ),
            ButtonSegment(
              value: ChartRange.year,
              label: Text(l10n.statistics_chart_year),
            ),
          ],
          selected: {range},
          onSelectionChanged: (selection) => ref
              .read(chartSelectionProvider.notifier)
              .selectRange(selection.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: _LineChart(
              range: range,
              points: points,
              onTouchPeriod: (period) => ref
                  .read(chartSelectionProvider.notifier)
                  .touchPeriod(period),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.range,
    required this.points,
    required this.onTouchPeriod,
  });

  final ChartRange range;
  final List<ChartPoint> points;

  /// 觸碰到某資料點時回報其期間 key;放開觸碰不會觸發(故保留選取)。
  final ValueChanged<String> onTouchPeriod;

  /// 橫軸標籤密度:週視圖逐天、月視圖每 7 天、年視圖隔月。
  double get _bottomInterval => switch (range) {
        ChartRange.week => 1,
        ChartRange.month => 7,
        ChartRange.year => 2,
      };

  /// 期間 key 轉橫軸標籤:day `yyyy-MM-dd` → `M/d`、month `yyyy-MM` → `M`。
  String _bottomLabel(String period) {
    final month = int.parse(period.substring(5, 7));
    if (range == ChartRange.year) return '$month';
    return '$month/${int.parse(period.substring(8))}';
  }

  /// 縱軸標籤:分鐘值,滿一小時改以小時顯示。
  String _leftLabel(double minutes) {
    if (minutes >= 60) {
      final h = minutes / 60;
      return '${h == h.roundToDouble() ? h.round() : h.toStringAsFixed(1)}h';
    }
    return '${minutes.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline);
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].listenTime.inSeconds / 60),
    ];
    final maxY = spots.fold(0.0, (max, s) => s.y > max ? s.y : max);

    return LineChart(
      LineChartData(
        minY: 0,
        // 全零時給固定高度,避免折線貼齊上緣;留 10% headroom。
        maxY: maxY == 0 ? 1 : maxY * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: scheme.primary,
            barWidth: 2,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            dotData: FlDotData(show: range == ChartRange.week),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                // 最頂端是 headroom 補的刻度,不顯示。
                if (value == meta.max || value == 0) {
                  return const SizedBox.shrink();
                }
                return Text(_leftLabel(value), style: labelStyle);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _bottomInterval,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (value != i.toDouble() || i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(_bottomLabel(points[i].period),
                      style: labelStyle),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) return;
            onTouchPeriod(points[spots.first.x.toInt()].period);
          },
          touchTooltipData: LineTouchTooltipData(
            // 邊緣節點的 tooltip 自動內縮,最多貼齊圖表邊緣不被截掉。
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${points[spot.x.toInt()].period}\n'
                  '${formatDuration(points[spot.x.toInt()].listenTime)}',
                  TextStyle(color: scheme.onInverseSurface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
