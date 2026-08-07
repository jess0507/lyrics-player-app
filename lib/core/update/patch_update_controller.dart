import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/update/shorebird_updater_provider.dart';

/// Shorebird patch 背景更新的進度狀態。
enum PatchUpdateState {
  idle,
  checking,
  downloading,

  /// patch 已下載完成(或先前已下載),重啟 App 後生效。
  restartReady,
  upToDate,
  error,
}

/// 背景檢查並下載 Shorebird patch。
///
/// checkForUpdate / update 在套件內部以 Isolate.run 於背景 isolate 執行,
/// 不會佔用 UI thread;下載完成後停在 [PatchUpdateState.restartReady],
/// 由 UI 提示使用者重啟。任何失敗都不影響 App 使用(下次啟動會再檢查)。
class PatchUpdateController extends Notifier<PatchUpdateState> {
  @override
  PatchUpdateState build() {
    // 等第一幀渲染完成後才開始(含 ShorebirdUpdater 的初始化),
    // 確保啟動畫面與首頁繪製不受影響。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkAndDownload();
    });
    return PatchUpdateState.idle;
  }

  Future<void> _checkAndDownload() async {
    final updater = ref.read(shorebirdUpdaterProvider);
    // debug build 或非 shorebird build 時引擎不可用,直接略過。
    if (!updater.isAvailable) return;

    try {
      state = PatchUpdateState.checking;
      final status = await updater.checkForUpdate();
      switch (status) {
        case UpdateStatus.outdated:
          state = PatchUpdateState.downloading;
          // auto_update: true 時引擎可能已在背景下載,此呼叫會立刻回傳
          // (IN_PROGRESS 視為成功),因此不能直接當作下載完成,
          // 需輪詢本機 patch 編號確認。
          await updater.update();
          await _waitForDownloadedPatch(updater);
        case UpdateStatus.restartRequired:
          state = PatchUpdateState.restartReady;
        case UpdateStatus.upToDate:
        case UpdateStatus.unavailable:
          state = PatchUpdateState.upToDate;
      }
    } catch (e, s) {
      debugPrint('Shorebird patch 更新失敗：$e');
      reportError(e, s, reason: 'Shorebird patch 更新失敗');
      state = PatchUpdateState.error;
    }
  }

  /// 輪詢直到新 patch 下載到本機(next 與 current 編號不同)才進入
  /// [PatchUpdateState.restartReady]。只讀本機狀態(背景 isolate FFI),
  /// 不打網路。逾時就安靜放棄提示——引擎的 auto_update 會繼續背景下載,
  /// 使用者下次自行重開 app 時仍會套用。
  Future<void> _waitForDownloadedPatch(ShorebirdUpdater updater) async {
    final current = (await updater.readCurrentPatch())?.number;
    for (var i = 0; i < 30; i++) {
      final next = (await updater.readNextPatch())?.number;
      if (next != current) {
        state = PatchUpdateState.restartReady;
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    state = PatchUpdateState.upToDate;
  }
}

final patchUpdateControllerProvider =
    NotifierProvider<PatchUpdateController, PatchUpdateState>(
      PatchUpdateController.new,
    );
