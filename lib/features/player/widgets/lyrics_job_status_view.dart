import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/lyrics/models/lyrics_job_stage.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_job_stage_provider.dart';
import 'package:seek_player/features/player/widgets/lyrics_cancel_job_action.dart';

/// 該 trackId 有進行中的自動產生/對齊工作時顯示,layout 比照 [LyricsView] 的
/// 空狀態(icon + 文字)。是否顯示由呼叫端依 `lyricsActiveJobProvider` 判斷;
/// 文字依 [lyricsJobStageProvider] 顯示目前階段,文案與通知列同一組字串,
/// 推不出階段時退回通用「處理中」。取消鈕見 [cancelLyricsJob]。
class LyricsJobStatusView extends ConsumerWidget {
  const LyricsJobStatusView({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final stage = ref.watch(lyricsJobStageProvider(trackId));
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lyrics_outlined, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _stageText(l10n, stage),
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

/// 階段 → 文案,與通知列各階段 / 已送出請求的字串一致。
String _stageText(
  AppLocalizations l10n,
  LyricsJobStage? stage,
) => switch (stage) {
  LyricsJobStage.generateCompressing => l10n.lyrics_ai_generate_compressing,
  LyricsJobStage.generateUploading => l10n.lyrics_ai_generate_uploading,
  LyricsJobStage.generateTranscribing => l10n.lyrics_ai_generate_transcribing,
  LyricsJobStage.generateRequestSent => l10n.lyrics_ai_generate_request_success,
  LyricsJobStage.alignCompressing => l10n.lyrics_auto_sync_compressing,
  LyricsJobStage.alignUploading => l10n.lyrics_auto_sync_uploading,
  LyricsJobStage.alignAligning => l10n.lyrics_auto_sync_aligning,
  LyricsJobStage.alignRequestSent => l10n.lyrics_auto_sync_request_success,
  null => l10n.lyrics_job_processing,
};
