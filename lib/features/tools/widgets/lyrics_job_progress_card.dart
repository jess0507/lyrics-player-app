import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/models/lyrics_job_stage.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_job_stage_provider.dart';
import 'package:seek_player/features/player/widgets/lyrics_cancel_job_action.dart';
import 'package:seek_player/features/player/widgets/lyrics_job_status_view.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 歌詞編輯頁的長時間任務進度卡:階段文字、第幾步 / 共幾步、進度條與取消鈕。
///
/// 本機階段(壓縮 / 上傳 / 處理)以已完成步數顯示確定進度;
/// 送出後等待雲端回結果的時間無法預估,改為不確定進度條。
/// 是否顯示由呼叫端依 `lyricsActiveJobProvider` 判斷。
class LyricsJobProgressCard extends ConsumerWidget {
  const LyricsJobProgressCard({super.key, required this.trackId});

  final String trackId;

  static const _totalSteps = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stage = ref.watch(lyricsJobStageProvider(trackId));
    final step = _stepOf(stage);
    // 最後一步(等待雲端)與推不出階段時都用不確定進度條。
    final value = step == null || step == _totalSteps
        ? null
        : step / _totalSteps;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lyricsJobStageText(l10n, stage),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (step != null)
                  Text(
                    l10n.tools_lyrics_job_step(step, _totalSteps),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: value,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    cancelLyricsJob(context, ref, trackId: trackId),
                child: Text(l10n.common_cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 階段 → 第幾步(1 起算):壓縮 → 上傳 → 處理 → 等待雲端結果。
/// 推不出階段(例如背景正在跑別首歌)回 null。
int? _stepOf(LyricsJobStage? stage) => switch (stage) {
  LyricsJobStage.generateCompressing || LyricsJobStage.alignCompressing => 1,
  LyricsJobStage.generateUploading || LyricsJobStage.alignUploading => 2,
  LyricsJobStage.generateTranscribing || LyricsJobStage.alignAligning => 3,
  LyricsJobStage.generateRequestSent || LyricsJobStage.alignRequestSent => 4,
  null => null,
};
