import 'package:flutter/material.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 開啟排序表單;按確定回傳新設定,取消或關閉回 null。
Future<TrackSort?> showTrackSortSheet(
  BuildContext context, {
  required TrackSort current,
}) {
  return showModalBottomSheet<TrackSort>(
    context: context,
    showDragHandle: true,
    builder: (context) => TrackSortSheet(initial: current),
  );
}

/// 排序表單:上半選欄位、下半選方向,底部取消 / 確定。
class TrackSortSheet extends StatefulWidget {
  const TrackSortSheet({super.key, required this.initial});

  final TrackSort initial;

  @override
  State<TrackSortSheet> createState() => _TrackSortSheetState();
}

class _TrackSortSheetState extends State<TrackSortSheet> {
  late var _field = widget.initial.field;
  late var _descending = widget.initial.descending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.tools_sort_by,
                style: theme.textTheme.titleLarge,
              ),
            ),
            RadioGroup<TrackSortField>(
              groupValue: _field,
              onChanged: (v) => setState(() => _field = v!),
              child: Column(
                children: [
                  for (final field in TrackSortField.values)
                    RadioListTile<TrackSortField>(
                      value: field,
                      title: Text(field.label(l10n)),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            RadioGroup<bool>(
              groupValue: _descending,
              onChanged: (v) => setState(() => _descending = v!),
              child: Column(
                children: [
                  for (final descending in const [true, false])
                    RadioListTile<bool>(
                      value: descending,
                      title: Text(
                        _field.orderLabel(l10n, descending: descending),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.common_cancel),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(TrackSort(field: _field, descending: _descending)),
                      child: Text(l10n.common_ok),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
