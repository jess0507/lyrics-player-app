import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';
import 'package:seek_player/features/lyrics/auto_sync/lyrics_auto_sync_controller.dart';
import 'package:seek_player/features/lyrics/auto_sync/lyrics_auto_sync_service.dart';

/// 觸發自動對時:立即以 toast 提示「已在背景對齊歌詞」,進度顯示在
/// 通知列(前景服務),不再擋 UI。成功時背景流程已寫入並 invalidate
/// [trackLyricsProvider],歌詞視圖自動切到同步;結果另以系統通知回報。
/// 失敗補一則 toast(仍在 app 內時可見);按通知「取消」則靜默收掉。
Future<void> runLyricsAutoSync(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String title,
  required LyricsAlignEngine engine,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final language = Localizations.localeOf(context).toLanguageTag();
  if (ref.read(lyricsAutoSyncControllerProvider(trackId)).isRunning) return;
  final controller = ref.read(
    lyricsAutoSyncControllerProvider(trackId).notifier,
  );

  showAppToast(l10n.lyrics_auto_sync_running_background);

  final ok = await controller.run(
    title: title,
    language: language,
    engine: engine,
  );

  // 背景任務可跑數分鐘,期間使用者可能已離開頁面;widget 已 dispose 就
  // 不能再碰 ref,結果已由系統通知回報,直接收尾。
  if (!context.mounted) return;
  final result = ref.read(lyricsAutoSyncControllerProvider(trackId));
  if (!ok) {
    if (result.status != LyricsAutoSyncStatus.cancelled) {
      // 使用者按通知列「取消」時靜默收掉,不當作失敗回報。
      showAppToast(_autoSyncErrorText(l10n, result));
    }
  }
}

String _autoSyncErrorText(AppLocalizations l10n, LyricsAutoSyncState result) =>
    switch (result.error) {
      LyricsAutoSyncError.notLoggedIn => l10n.lyrics_auto_sync_need_login,
      LyricsAutoSyncError.rateLimited => l10n.lyrics_auto_sync_rate_limited,
      LyricsAutoSyncError.noAudio => l10n.lyrics_auto_sync_no_audio,
      LyricsAutoSyncError.network => l10n.lyrics_auto_sync_network,
      LyricsAutoSyncError.busy => result.activeTitle != null
          ? l10n.lyrics_background_busy_named(result.activeTitle!)
          : l10n.lyrics_background_busy,
      _ => l10n.lyrics_auto_sync_failed,
    };
