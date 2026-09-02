import 'package:flutter/material.dart';

/// 調整面板上方的常用值快選列:每個 [values] 一顆 [ChoiceChip],
/// 點選即套用該值。選取狀態完全由 [isSelected] 依目前值判斷,
/// 因此滑桿滑到常用值時對應的 chip 也會同步顯示為選取。
/// chip 採緊湊尺寸(小字、窄內距、無點擊留白),讓 6 顆能排在同一列;
/// 螢幕過窄放不下時才折行。
class PresetChips<T> extends StatelessWidget {
  const PresetChips({
    super.key,
    required this.values,
    required this.labelOf,
    required this.isSelected,
    required this.onSelected,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final bool Function(T value) isSelected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelOf(value), style: labelStyle),
            selected: isSelected(value),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}
