import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crash_reporter.dart';
import '../background/lyrics_background_protocol.dart';
import '../background/lyrics_background_runner.dart';
import '../background/lyrics_l10n_resolver.dart';
import '../providers/lyrics_pending_sync_store.dart';
import 'lyrics_auto_sync_service.dart';

/// 對時整體狀態。
enum LyricsAutoSyncStatus { idle, running, success, failure, cancelled }

/// 某曲對時的當前狀態:執行中帶 [step],失敗帶 [error]。
class LyricsAutoSyncState {
  const LyricsAutoSyncState({
    this.status = LyricsAutoSyncStatus.idle,
    this.step,
    this.error,
    this.activeTitle,
  });

  final LyricsAutoSyncStatus status;
  final LyricsAutoSyncStep? step;
  final LyricsAutoSyncError? error;

  /// [error] 為 [LyricsAutoSyncError.busy] 且是後端回報「別首歌正在處理中」
  /// 時,該曲的曲名,供訊息顯示;其餘情況為 null。
  final String? activeTitle;

  bool get isRunning => status == LyricsAutoSyncStatus.running;
}

/// 以 trackId 為 key 的對時控制器:驅動 [LyricsAutoSyncService] 並把階段 /
/// 結果寫成 [LyricsAutoSyncState],供進度對話框與選單即時反映。
///
/// Android 交由 [LyricsBackgroundRunner](前景服務 + 背景 isolate)執行,
/// app 從最近工作列滑掉也繼續;其他平台維持在本 isolate 直接執行。
class LyricsAutoSyncController
    extends FamilyNotifier<LyricsAutoSyncState, String> {
  @override
  LyricsAutoSyncState build(String arg) => const LyricsAutoSyncState();

  /// 執行對時;成功回 true。已在執行中則忽略並回 false。
  /// [engine] 指定後端對齊引擎(aeneas / WhisperX)。
  Future<bool> run({
    required String title,
    required String language,
    required LyricsAlignEngine engine,
  }) async {
    if (state.isRunning) return false;
    state = const LyricsAutoSyncState(
      status: LyricsAutoSyncStatus.running,
      step: LyricsAutoSyncStep.compressing,
    );
    // 送出前先在 main isolate 記到本地待同步清單:無論之後實際執行是走
    // Android 背景 isolate 還是本 isolate,LyricsPendingSyncService(常駐
    // main isolate)都能立刻開始監聽 Firestore 狀態,不需背景 isolate 另外
    // 回報——也不怕 app 中途被滑掉,這筆紀錄已經落地。
    debugPrint('[LyricsAutoSyncController] trackId:$arg, 加入 pendingSyncStore');
    await ref.read(lyricsPendingSyncStoreProvider.notifier).add(
      arg,
      LyricsPendingSyncJob(mode: LyricsBackgroundMode.align, title: title),
    );
    final success = Platform.isAndroid
        ? await _runInBackground(title: title, language: language, engine: engine)
        : await _runInline(title: title, language: language, engine: engine);
    if (!success) {
      // 沒有真的送出背景工作(取消 / busy / 過程中失敗),沒有任何後端 job
      // 可等,清掉剛剛預先加的紀錄,避免白等一個不存在的工作。
      debugPrint('[LyricsAutoSyncController] trackId:$arg, 未成功送出,移除 pendingSyncStore');
      await ref.read(lyricsPendingSyncStoreProvider.notifier).remove(arg);
    }
    return success;
  }

  /// Android:走前景服務。通知文字在此以當前語系解析好隨請求帶出,
  /// 背景 isolate 不需存取 l10n。
  Future<bool> _runInBackground({
    required String title,
    required String language,
    required LyricsAlignEngine engine,
  }) async {
    final l10n = resolveLyricsL10n(ref);
    final result = await ref
        .read(lyricsBackgroundRunnerProvider)
        .run(
          LyricsBackgroundRequest(
            mode: LyricsBackgroundMode.align,
            trackId: arg,
            title: title,
            language: language,
            engineName: engine.wireName,
            stepLabels: {
              LyricsAutoSyncStep.compressing.name:
                  l10n.lyrics_auto_sync_compressing,
              LyricsAutoSyncStep.uploading.name: l10n.lyrics_auto_sync_uploading,
              LyricsAutoSyncStep.aligning.name: l10n.lyrics_auto_sync_aligning,
            },
            cancelLabel: l10n.common_cancel,
            // 這裡只代表「callable 呼叫成功 / 失敗」,不是歌詞真的做完了;
            // 真正完成時的確認通知由 LyricsPendingSyncService 另外發。
            doneLabel: l10n.lyrics_auto_sync_request_success,
            failedLabel: l10n.lyrics_auto_sync_request_failed,
          ),
          onStep: (stepName) {
            final step = LyricsAutoSyncStep.values.asNameMap()[stepName];
            if (step != null) {
              state = LyricsAutoSyncState(
                status: LyricsAutoSyncStatus.running,
                step: step,
              );
            }
          },
        );
    switch (result.status) {
      case LyricsBackgroundStatus.success:
        state = const LyricsAutoSyncState(status: LyricsAutoSyncStatus.success);
        return true;
      case LyricsBackgroundStatus.cancelled:
        state = const LyricsAutoSyncState(
          status: LyricsAutoSyncStatus.cancelled,
        );
        return false;
      case LyricsBackgroundStatus.busy:
        state = const LyricsAutoSyncState(
          status: LyricsAutoSyncStatus.failure,
          error: LyricsAutoSyncError.busy,
        );
        return false;
      case LyricsBackgroundStatus.error:
        state = LyricsAutoSyncState(
          status: LyricsAutoSyncStatus.failure,
          error:
              LyricsAutoSyncError.values.asNameMap()[result.errorName] ??
              LyricsAutoSyncError.unknown,
          activeTitle: result.activeTitle,
        );
        return false;
    }
  }

  /// 非 Android:於本 isolate 直接執行(原行為)。
  Future<bool> _runInline({
    required String title,
    required String language,
    required LyricsAlignEngine engine,
  }) async {
    try {
      await ref
          .read(lyricsAutoSyncServiceProvider)
          .autoSync(
            trackId: arg,
            title: title,
            language: language,
            engine: engine,
            onStep: (step) => state = LyricsAutoSyncState(
              status: LyricsAutoSyncStatus.running,
              step: step,
            ),
          );
      state = const LyricsAutoSyncState(status: LyricsAutoSyncStatus.success);
      return true;
    } on LyricsAutoSyncException catch (e) {
      state = LyricsAutoSyncState(
        status: LyricsAutoSyncStatus.failure,
        error: e.error,
        activeTitle: e.activeTitle,
      );
      return false;
    } catch (e, s) {
      reportError(e, s, reason: '歌詞對時：未預期錯誤');
      state = const LyricsAutoSyncState(
        status: LyricsAutoSyncStatus.failure,
        error: LyricsAutoSyncError.unknown,
      );
      return false;
    }
  }

}

final lyricsAutoSyncControllerProvider =
    NotifierProvider.family<
      LyricsAutoSyncController,
      LyricsAutoSyncState,
      String
    >(LyricsAutoSyncController.new);
