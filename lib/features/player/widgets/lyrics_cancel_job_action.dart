import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_runner.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 取消該 trackId 進行中的自動產生/對時工作。只處理本機端:還在本機
/// 壓縮/上傳/呼叫 callable(僅 Android 前景服務)就中止該階段;後端已經
/// 開始處理(工作已進 Cloud Tasks)則不管,單純把本機的待同步紀錄清掉,
/// 讓 UI 立刻恢復、可以馬上處理下一首。完成後以 toast 提示。
/// [source] 標示取消入口(操作面板 / 狀態視圖 / 工具頁進度卡),供 GA 區分。
Future<void> cancelLyricsJob(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required AnalyticsSource source,
}) async {
  logAnalyticsAction(LyricsAction.cancelJob, source: source);
  // 取消過程會讓「工作進行中」狀態消失,顯示取消鈕的 widget 隨之被移除,
  // ref 與 context 都會失效;需要的東西一律在第一個 await 前取好。
  final runner = ref.read(lyricsBackgroundRunnerProvider);
  final pendingStore = ref.read(lyricsPendingSyncStoreProvider.notifier);
  final repository = ref.read(lyricsRepositoryProvider);
  final message = AppLocalizations.of(context)!.lyrics_job_cancelled;
  if (Platform.isAndroid) {
    await runner.cancel(trackId);
  }
  await pendingStore.remove(trackId);
  await repository.clearJob(trackId);
  showAppToast(message);
}
