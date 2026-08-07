import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_controller.dart';
import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_snack_bar.dart';

/// 觸發自動產生歌詞:立即以 SnackBar 提示「已在背景產生歌詞」,進度顯示在
/// 通知列(前景服務),不再擋 UI。成功時背景流程已寫入並 invalidate
/// `trackLyricsProvider`,歌詞視圖自動顯示產物;結果另以系統通知回報。
/// 失敗補一則 SnackBar(仍在 app 內時可見);按通知「取消」則靜默收掉。
Future<void> runLyricsAiGenerate(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  if (ref.read(lyricsAutoGenerateControllerProvider(trackId)).isRunning) {
    debugPrint('[LyricsAutoGen] 已在執行中,略過 trackId=$trackId');
    return;
  }

  debugPrint('[LyricsAutoGen] 開始 trackId=$trackId title="$title"');
  messenger.showAppSnackBar(l10n.lyrics_ai_generate_running_background);

  final controller = ref.read(
    lyricsAutoGenerateControllerProvider(trackId).notifier,
  );
  final ok = await controller.run(title: title);

  // 背景任務可跑數分鐘,期間使用者可能已離開頁面;widget 已 dispose 就
  // 不能再碰 ref,結果已由系統通知回報,直接收尾。
  if (!context.mounted) return;
  final result = ref.read(lyricsAutoGenerateControllerProvider(trackId));
  if (ok) {
    debugPrint('[LyricsAutoGen] 成功 trackId=$trackId');
  } else if (result.status == LyricsAutoGenerateStatus.cancelled) {
    debugPrint('[LyricsAutoGen] 已取消 trackId=$trackId');
  } else {
    debugPrint('[LyricsAutoGen] 失敗 trackId=$trackId error=${result.error}');
    messenger.showAppSnackBar(_aiGenerateErrorText(l10n, result));
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
  LyricsAutoGenerateError.busy => result.activeTitle != null
      ? l10n.lyrics_background_busy_named(result.activeTitle!)
      : l10n.lyrics_background_busy,
  _ => l10n.lyrics_ai_generate_failed,
};
