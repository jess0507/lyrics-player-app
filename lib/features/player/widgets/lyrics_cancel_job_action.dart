import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_runner.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 取消該 trackId 進行中的自動產生/對時工作。只處理本機端:還在本機
/// 壓縮/上傳/呼叫 callable(僅 Android 前景服務)就中止該階段;後端已經
/// 開始處理(工作已進 Cloud Tasks)則不管,單純把本機的待同步紀錄清掉,
/// 讓 UI 立刻恢復、可以馬上處理下一首。完成後以 toast 提示。
Future<void> cancelLyricsJob(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
}) async {
  if (Platform.isAndroid) {
    await ref.read(lyricsBackgroundRunnerProvider).cancel(trackId);
  }
  await ref.read(lyricsPendingSyncStoreProvider.notifier).remove(trackId);
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  showAppToast(l10n.lyrics_job_cancelled);
}
