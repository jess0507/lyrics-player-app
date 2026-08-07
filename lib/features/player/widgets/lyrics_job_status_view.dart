import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/player/widgets/lyrics_cancel_job_action.dart';

/// 該 trackId 有進行中的自動產生/對齊工作時顯示,layout 比照 [LyricsView] 的
/// 空狀態(icon + 文字)。是否顯示由呼叫端依 `lyricsActiveJobProvider` 判斷,
/// 本身只負責畫面,不區分實際處理階段。取消鈕見 [cancelLyricsJob]。
class LyricsJobStatusView extends ConsumerWidget {
  const LyricsJobStatusView({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lyrics_outlined, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.lyrics_job_processing,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => cancelLyricsJob(context, ref, trackId: trackId),
            child: Text(l10n.common_cancel),
          ),
        ],
      ),
    );
  }
}
