import 'package:flutter/material.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/format.dart';
import 'package:seek_player/features/music_list/models/track.dart';

/// 顯示曲目詳細資訊的彈出對話框(標題、演出者、時長、檔案位置)。
Future<void> showTrackInfoDialog(BuildContext context, Track track) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(track.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: l10n.track_info_artist,
            value: track.artist ?? l10n.common_unknown,
          ),
          _InfoRow(
            label: l10n.track_info_duration,
            value: track.duration == null
                ? l10n.common_unknown
                : formatDuration(track.duration!),
          ),
          _InfoRow(label: l10n.track_info_location, value: track.uri),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_ok),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
