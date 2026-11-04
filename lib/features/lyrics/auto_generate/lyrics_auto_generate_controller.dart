import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/lyrics/background/lyrics_background_protocol.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_runner.dart';
import 'package:seek_player/features/lyrics/background/lyrics_l10n_resolver.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';
import 'package:seek_player/features/lyrics/services/lyrics_job_id.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';
import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_service.dart';

/// 自動產生整體狀態。
enum LyricsAutoGenerateStatus { idle, running, success, failure, cancelled }

/// 某曲自動產生的當前狀態:執行中帶 [step],失敗帶 [error]。
class LyricsAutoGenerateState {
  const LyricsAutoGenerateState({
    this.status = LyricsAutoGenerateStatus.idle,
    this.step,
    this.error,
    this.activeTitle,
  });

  final LyricsAutoGenerateStatus status;
  final LyricsAutoGenerateStep? step;
  final LyricsAutoGenerateError? error;

  /// [error] 為 [LyricsAutoGenerateError.busy] 且是後端回報「別首歌正在
  /// 處理中」時,該曲的曲名,供訊息顯示;其餘情況為 null。
  final String? activeTitle;

  bool get isRunning => status == LyricsAutoGenerateStatus.running;
}

/// 以 trackId 為 key 的自動產生控制器:驅動 [LyricsAutoGenerateService] 並把
/// 階段 / 結果寫成 [LyricsAutoGenerateState],供進度對話框與選單即時反映。
///
/// 交由 [LyricsBackgroundRunner](Android 前景服務 + 背景 isolate)執行,
/// app 從最近工作列滑掉也繼續。
class LyricsAutoGenerateController
    extends FamilyNotifier<LyricsAutoGenerateState, String> {
  @override
  LyricsAutoGenerateState build(String arg) => const LyricsAutoGenerateState();

  /// 執行自動產生;成功回 true。已在執行中則忽略並回 false。
  Future<bool> run({required String title}) async {
    if (state.isRunning) return false;
    state = const LyricsAutoGenerateState(
      status: LyricsAutoGenerateStatus.running,
      step: LyricsAutoGenerateStep.compressing,
    );
    // 送出前先在 main isolate 記到本地待同步清單:LyricsPendingSyncService
    // (常駐 main isolate)能立刻開始監聽 Firestore 狀態,不需背景 isolate
    // 另外回報——也不怕 app 中途被滑掉,這筆紀錄已經落地。
    debugPrint(
      '[LyricsAutoGenerateController] trackId:$arg, 加入 pendingSyncStore',
    );
    // 每次送出都產生新的 jobId 作為後端任務文件 id,記在 LyricsEntity 與
    // 待同步清單(LyricsPendingSyncService 依它監聽)。
    final jobId = newLyricsJobId();
    await ref
        .read(lyricsRepositoryProvider)
        .beginJob(arg, jobId: jobId, title: title);
    await ref
        .read(lyricsPendingSyncStoreProvider.notifier)
        .add(
          arg,
          LyricsPendingSyncJob(
            jobId: jobId,
            mode: LyricsBackgroundMode.generate,
            title: title,
          ),
        );
    final success = await _runInBackground(jobId: jobId, title: title);
    if (!success) {
      // 沒有真的送出背景工作(取消 / busy / 過程中失敗),沒有任何後端 job
      // 可等,清掉剛剛預先加的紀錄,避免白等一個不存在的工作。
      debugPrint(
        '[LyricsAutoGenerateController] trackId:$arg, 未成功送出,移除 pendingSyncStore',
      );
      await ref.read(lyricsPendingSyncStoreProvider.notifier).remove(arg);
      await ref.read(lyricsRepositoryProvider).clearJob(arg);
    }
    return success;
  }

  /// 走 Android 前景服務。通知文字在此以當前語系解析好隨請求帶出,
  /// 背景 isolate 不需存取 l10n。
  Future<bool> _runInBackground({
    required String jobId,
    required String title,
  }) async {
    final l10n = resolveLyricsL10n(ref);
    final result = await ref
        .read(lyricsBackgroundRunnerProvider)
        .run(
          LyricsBackgroundRequest(
            mode: LyricsBackgroundMode.generate,
            trackId: arg,
            jobId: jobId,
            title: title,
            stepLabels: {
              LyricsAutoGenerateStep.compressing.name:
                  l10n.lyrics_ai_generate_compressing,
              LyricsAutoGenerateStep.uploading.name:
                  l10n.lyrics_ai_generate_uploading,
              LyricsAutoGenerateStep.transcribing.name:
                  l10n.lyrics_ai_generate_transcribing,
            },
            cancelLabel: l10n.common_cancel,
            // 這裡只代表「callable 呼叫成功 / 失敗」,不是歌詞真的做完了;
            // 真正完成時的確認通知由 LyricsPendingSyncService 另外發。
            doneLabel: l10n.lyrics_ai_generate_request_success,
            failedLabel: l10n.lyrics_ai_generate_request_failed,
          ),
          onStep: (stepName) {
            final step = LyricsAutoGenerateStep.values.asNameMap()[stepName];
            if (step != null) {
              state = LyricsAutoGenerateState(
                status: LyricsAutoGenerateStatus.running,
                step: step,
              );
            }
          },
        );
    switch (result.status) {
      case LyricsBackgroundStatus.success:
        state = const LyricsAutoGenerateState(
          status: LyricsAutoGenerateStatus.success,
        );
        return true;
      case LyricsBackgroundStatus.cancelled:
        state = const LyricsAutoGenerateState(
          status: LyricsAutoGenerateStatus.cancelled,
        );
        return false;
      case LyricsBackgroundStatus.busy:
        state = const LyricsAutoGenerateState(
          status: LyricsAutoGenerateStatus.failure,
          error: LyricsAutoGenerateError.busy,
        );
        return false;
      case LyricsBackgroundStatus.error:
        state = LyricsAutoGenerateState(
          status: LyricsAutoGenerateStatus.failure,
          error:
              LyricsAutoGenerateError.values.asNameMap()[result.errorName] ??
              LyricsAutoGenerateError.unknown,
          activeTitle: result.activeTitle,
        );
        return false;
    }
  }
}

final lyricsAutoGenerateControllerProvider =
    NotifierProvider.family<
      LyricsAutoGenerateController,
      LyricsAutoGenerateState,
      String
    >(LyricsAutoGenerateController.new);
