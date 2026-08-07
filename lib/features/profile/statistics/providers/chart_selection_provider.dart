import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/profile/statistics/providers/chart_series_provider.dart';

/// 統計頁圖表的選取狀態:目前視圖範圍 + 觸碰選中的期間 key。
///
/// _StatCard 依此呈現——未選任何節點時顯示整個範圍的彙總,觸碰某資料點
/// 則顯示該期間;放開觸碰保留選取(不重置),切換範圍才清除選取。
class ChartSelection {
  const ChartSelection({required this.range, this.touchedPeriod});

  final ChartRange range;

  /// 觸碰選中的期間 key(day `yyyy-MM-dd` 或 month `yyyy-MM`);
  /// null 表示顯示整個 [range] 的彙總。
  final String? touchedPeriod;
}

class ChartSelectionController extends Notifier<ChartSelection> {
  @override
  ChartSelection build() => const ChartSelection(range: ChartRange.week);

  /// 切換視圖範圍;清除已選節點,回到該範圍的彙總。
  void selectRange(ChartRange range) =>
      state = ChartSelection(range: range);

  /// 觸碰選中某期間(放開不呼叫此方法,故保留最後選取)。
  void touchPeriod(String period) =>
      state = ChartSelection(range: state.range, touchedPeriod: period);
}

final chartSelectionProvider =
    NotifierProvider<ChartSelectionController, ChartSelection>(
      ChartSelectionController.new,
    );
