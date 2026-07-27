import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crash_reporter.dart';
import '../background/lyrics_background_protocol.dart';
import '../background/lyrics_background_runner.dart';
import '../background/lyrics_l10n_resolver.dart';
import '../providers/lyrics_pending_sync_store.dart';
import 'lyrics_auto_generate_service.dart';

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
/// Android 交由 [LyricsBackgroundRunner](前景服務 + 背景 isolate)執行,
/// app 從最近工作列滑掉也繼續;其他平台維持在本 isolate 直接執行。
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
    // 送出前先在 main isolate 記到本地待同步清單:無論之後實際執行是走
    // Android 背景 isolate 還是本 isolate,LyricsPendingSyncService(常駐
    // main isolate)都能立刻開始監聽 Firestore 狀態,不需背景 isolate 另外
    // 回報——也不怕 app 中途被滑掉,這筆紀錄已經落地。
    debugPrint('[LyricsAutoGenerateController] trackId:$arg, 加入 pendingSyncStore');
    await ref.read(lyricsPendingSyncStoreProvider.notifier).add(
      arg,
      LyricsPendingSyncJob(mode: LyricsBackgroundMode.generate, title: title),
    );
    final success = Platform.isAndroid
        ? await _runInBackground(title: title)
        : await _runInline(title: title);
    if (!success) {
      // 沒有真的送出背景工作(取消 / busy / 過程中失敗),沒有任何後端 job
      // 可等,清掉剛剛預先加的紀錄,避免白等一個不存在的工作。
      debugPrint(
        '[LyricsAutoGenerateController] trackId:$arg, 未成功送出,移除 pendingSyncStore',
      );
      await ref.read(lyricsPendingSyncStoreProvider.notifier).remove(arg);
    }
    return success;
  }

  /// Android:走前景服務。通知文字在此以當前語系解析好隨請求帶出,
  /// 背景 isolate 不需存取 l10n。
  Future<bool> _runInBackground({required String title}) async {
    final l10n = resolveLyricsL10n(ref);
    final result = await ref
        .read(lyricsBackgroundRunnerProvider)
        .run(
          LyricsBackgroundRequest(
            mode: LyricsBackgroundMode.generate,
            trackId: arg,
            title: title,
            stepLabels: {
              LyricsAutoGenerateStep.compressing.name:
                  l10n.lyrics_auto_generate_compressing,
              LyricsAutoGenerateStep.uploading.name:
                  l10n.lyrics_auto_generate_uploading,
              LyricsAutoGenerateStep.transcribing.name:
                  l10n.lyrics_auto_generate_transcribing,
            },
            cancelLabel: l10n.common_cancel,
            // 這裡只代表「callable 呼叫成功 / 失敗」,不是歌詞真的做完了;
            // 真正完成時的確認通知由 LyricsPendingSyncService 另外發。
            doneLabel: l10n.lyrics_auto_generate_request_success,
            failedLabel: l10n.lyrics_auto_generate_request_failed,
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

  /// 非 Android:於本 isolate 直接執行(原行為)。
  Future<bool> _runInline({required String title}) async {
    try {
      await ref
          .read(lyricsAutoGenerateServiceProvider)
          .generate(
            trackId: arg,
            title: title,
            onStep: (step) => state = LyricsAutoGenerateState(
              status: LyricsAutoGenerateStatus.running,
              step: step,
            ),
          );
      state = const LyricsAutoGenerateState(
        status: LyricsAutoGenerateStatus.success,
      );
      return true;
    } on LyricsAutoGenerateException catch (e) {
      state = LyricsAutoGenerateState(
        status: LyricsAutoGenerateStatus.failure,
        error: e.error,
        activeTitle: e.activeTitle,
      );
      return false;
    } catch (e, s) {
      reportError(e, s, reason: '自動產生歌詞：未預期錯誤');
      state = const LyricsAutoGenerateState(
        status: LyricsAutoGenerateStatus.failure,
        error: LyricsAutoGenerateError.unknown,
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
