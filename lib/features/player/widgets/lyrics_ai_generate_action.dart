import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_controller.dart';
import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_service.dart';
import 'package:seek_player/core/update/upgrade_required_prompt.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 觸發自動產生歌詞:立即以 toast 提示「已在背景產生歌詞」,進度顯示在
/// 通知列(前景服務),不再擋 UI。成功時背景流程已寫入並 invalidate
/// `trackLyricsProvider`,歌詞視圖自動顯示產物;結果另以系統通知回報。
/// 失敗補一則 toast(仍在 app 內時可見);按通知「取消」則靜默收掉。
Future<void> runLyricsAiGenerate(
  BuildContext context,
  WidgetRef ref, {
  required String pathKey,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (ref.read(lyricsAutoGenerateControllerProvider(pathKey)).isRunning) {
    debugPrint('[LyricsAutoGen] 已在執行中,略過 pathKey=$pathKey');
    return;
  }

  debugPrint('[LyricsAutoGen] 開始 pathKey=$pathKey title="$title"');
  showAppToast(l10n.lyrics_ai_generate_running_background);

  final controller = ref.read(
    lyricsAutoGenerateControllerProvider(pathKey).notifier,
  );
  final ok = await controller.run(title: title);

  // 背景任務可跑數分鐘,期間使用者可能已離開頁面;widget 已 dispose 就
  // 不能再碰 ref,結果已由系統通知回報,直接收尾。
  // 已離開頁面時讀不到細節,只記成功 / 失敗。
  if (!context.mounted) {
    logAnalyticsAction(
      LyricsAction.aiGenerateSubmit,
      result: ok ? AnalyticsResult.success : AnalyticsResult.failure,
    );
    return;
  }
  final result = ref.read(lyricsAutoGenerateControllerProvider(pathKey));
  logAnalyticsAction(
    LyricsAction.aiGenerateSubmit,
    result: ok
        ? AnalyticsResult.success
        : result.status == LyricsAutoGenerateStatus.cancelled
        ? AnalyticsResult.cancelled
        : result.error ?? AnalyticsResult.failure,
  );
  if (ok) {
    debugPrint('[LyricsAutoGen] 成功 pathKey=$pathKey');
  } else if (result.status == LyricsAutoGenerateStatus.cancelled) {
    debugPrint('[LyricsAutoGen] 已取消 pathKey=$pathKey');
  } else {
    debugPrint('[LyricsAutoGen] 失敗 pathKey=$pathKey error=${result.error}');
    if (result.error == LyricsAutoGenerateError.upgradeRequired) {
      showUpgradeRequiredPrompt(context);
    } else {
      showAppToast(_aiGenerateErrorText(l10n, result));
    }
  }
}

String _aiGenerateErrorText(
  AppLocalizations l10n,
  LyricsAutoGenerateState result,
) => switch (result.error) {
  LyricsAutoGenerateError.notLoggedIn => l10n.lyrics_ai_generate_need_login,
  LyricsAutoGenerateError.rateLimited => l10n.lyrics_ai_generate_rate_limited,
  LyricsAutoGenerateError.noAudio => l10n.lyrics_ai_generate_no_audio,
  LyricsAutoGenerateError.network => l10n.lyrics_ai_generate_network,
  LyricsAutoGenerateError.upgradeRequired => l10n.lyrics_upgrade_required,
  LyricsAutoGenerateError.busy =>
    result.activeTitle != null
        ? l10n.lyrics_background_busy_named(result.activeTitle!)
        : l10n.lyrics_background_busy,
  _ => l10n.lyrics_ai_generate_failed,
};
