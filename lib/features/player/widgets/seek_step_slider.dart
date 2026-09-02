import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/widgets/adjustment_bottom_sheet.dart';
import 'package:seek_player/features/player/widgets/preset_chips.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

/// 快進 / 快退秒數的可選檔位;滑桿以此為刻度,與速度滑桿一樣有明顯間隔。
const List<int> kSeekStepChoices = [1, 2, 3, 5, 10, 15, 20, 30, 45, 60];

/// 面板上方的常用秒數快選,為 [kSeekStepChoices] 的子集。
const List<int> _kSeekStepPresets = [5, 10, 15, 30];

/// 快進 / 快退秒數調整面板:在 [kSeekStepChoices] 之間切換,調整時即時寫入
/// 設定(持久化並同步至雲端),播放頁控制列立即反映新的步進量;重置回預設 5 秒。
/// 與播放速度面板同以 [AdjustmentBottomSheet] 呈現,外觀一致。
void showSeekStepSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return Consumer(
        builder: (context, ref, _) => AdjustmentBottomSheet(
          title: l10n.player_seek_step,
          onReset: () => ref
              .read(settingsControllerProvider.notifier)
              .setSeekStepSeconds(SettingsState.kDefaultSeekStepSeconds),
          child: const SeekStepSlider(),
        ),
      );
    },
  );
}

/// 快進 / 快退秒數滑桿:上方為常用秒數快選,下方顯示目前秒數與刻度滑桿,
/// 調整時即時寫入設定。
/// 滑桿以檔位索引為值,秒數不在檔位內(例如雲端還原的舊值)時顯示最接近的檔位。
class SeekStepSlider extends ConsumerWidget {
  const SeekStepSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(
      settingsControllerProvider.select((s) => s.seekStepSeconds),
    );
    final index = _nearestIndex(seconds);
    final notifier = ref.read(settingsControllerProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PresetChips<int>(
          values: _kSeekStepPresets,
          labelOf: (v) => '${v}s',
          isSelected: (v) => v == seconds,
          onSelected: notifier.setSeekStepSeconds,
        ),
        const SizedBox(height: 8),
        Text('${seconds}s', style: Theme.of(context).textTheme.headlineMedium),
        Slider(
          min: 0,
          max: (kSeekStepChoices.length - 1).toDouble(),
          divisions: kSeekStepChoices.length - 1,
          value: index.toDouble(),
          label: '${kSeekStepChoices[index]}s',
          onChanged: (v) =>
              notifier.setSeekStepSeconds(kSeekStepChoices[v.round()]),
        ),
      ],
    );
  }

  /// 找出與 [seconds] 最接近的檔位索引。
  static int _nearestIndex(int seconds) {
    var best = 0;
    for (var i = 1; i < kSeekStepChoices.length; i++) {
      if ((kSeekStepChoices[i] - seconds).abs() <
          (kSeekStepChoices[best] - seconds).abs()) {
        best = i;
      }
    }
    return best;
  }
}
