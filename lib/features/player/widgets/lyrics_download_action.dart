import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/lyrics/services/lyrics_export_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 觸發下載歌詞並以 toast 回報結果;取消存檔不提示。
Future<void> runLyricsDownload(
  BuildContext context,
  WidgetRef ref, {
  required String pathKey,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final saved = await ref
        .read(lyricsExportServiceProvider)
        .exportForTrack(pathKey: pathKey, title: title);
    logAnalyticsAction(
      LyricsAction.downloadResult,
      result: saved ? AnalyticsResult.success : AnalyticsResult.cancelled,
    );
    if (!saved) return; // 使用者取消
    showAppToast(l10n.lyrics_download_success);
  } catch (e, s) {
    logAnalyticsAction(
      LyricsAction.downloadResult,
      result: AnalyticsResult.failure,
    );
    reportError(e, s, reason: '下載歌詞失敗');
    showAppToast(l10n.lyrics_download_failed);
  }
}
