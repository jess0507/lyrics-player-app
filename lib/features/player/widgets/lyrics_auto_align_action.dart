import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/update/upgrade_required_prompt.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';
import 'package:seek_player/features/lyrics/auto_align/lyrics_auto_align_controller.dart';
import 'package:seek_player/features/lyrics/auto_align/lyrics_auto_align_service.dart';

/// 觸發自動對時:立即以 toast 提示「已在背景對齊歌詞」,進度顯示在
/// 通知列(前景服務),不再擋 UI。成功時背景流程已寫入並 invalidate
/// [trackLyricsProvider],歌詞視圖自動切到同步;結果另以系統通知回報。
/// 失敗補一則 toast(仍在 app 內時可見);按通知「取消」則靜默收掉。
Future<void> runLyricsAutoAlign(
  BuildContext context,
  WidgetRef ref, {
  required String pathKey,
  required String title,
  required LyricsAlignEngine engine,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final language = Localizations.localeOf(context).toLanguageTag();
  if (ref.read(lyricsAutoAlignControllerProvider(pathKey)).isRunning) return;
  final controller = ref.read(
    lyricsAutoAlignControllerProvider(pathKey).notifier,
  );

  showAppToast(l10n.lyrics_auto_align_running_background);

  final ok = await controller.run(
    title: title,
    language: language,
    engine: engine,
  );

  // 背景任務可跑數分鐘,期間使用者可能已離開頁面;widget 已 dispose 就
  // 不能再碰 ref,結果已由系統通知回報,直接收尾。
  // 已離開頁面時讀不到細節,只記成功 / 失敗。
  if (!context.mounted) {
    logAnalyticsAction(
      LyricsAction.autoAlignSubmit,
      option: engine,
      result: ok ? AnalyticsResult.success : AnalyticsResult.failure,
    );
    return;
  }
  final result = ref.read(lyricsAutoAlignControllerProvider(pathKey));
  logAnalyticsAction(
    LyricsAction.autoAlignSubmit,
    option: engine,
    result: ok
        ? AnalyticsResult.success
        : result.status == LyricsAutoAlignStatus.cancelled
        ? AnalyticsResult.cancelled
        : result.error ?? AnalyticsResult.failure,
  );
  if (!ok) {
    if (result.status != LyricsAutoAlignStatus.cancelled) {
      // 使用者按通知列「取消」時靜默收掉,不當作失敗回報。
      if (result.error == LyricsAutoAlignError.upgradeRequired) {
        showUpgradeRequiredPrompt(context);
      } else {
        showAppToast(_autoAlignErrorText(l10n, result));
      }
    }
  }
}

String _autoAlignErrorText(
  AppLocalizations l10n,
  LyricsAutoAlignState result,
) => switch (result.error) {
  LyricsAutoAlignError.notLoggedIn => l10n.lyrics_auto_align_need_login,
  LyricsAutoAlignError.rateLimited => l10n.lyrics_auto_align_rate_limited,
  LyricsAutoAlignError.noAudio => l10n.lyrics_auto_align_no_audio,
  LyricsAutoAlignError.network => l10n.lyrics_auto_align_network,
  LyricsAutoAlignError.upgradeRequired => l10n.lyrics_upgrade_required,
  LyricsAutoAlignError.busy =>
    result.activeTitle != null
        ? l10n.lyrics_background_busy_named(result.activeTitle!)
        : l10n.lyrics_background_busy,
  _ => l10n.lyrics_auto_align_failed,
};
