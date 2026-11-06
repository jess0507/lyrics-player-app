import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/lyrics/services/track_audio_resolver.dart';
import 'package:seek_player/features/lyrics/usage_limit/audio_duration_probe.dart';
import 'package:seek_player/features/lyrics/usage_limit/lyrics_usage_limit_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 雲端歌詞功能(自動產生 / 自動對時)執行前的用量關卡。
///
/// 先量 [pathKey] 對應音訊的長度,再確認本月額度未用完、且剩餘額度足以
/// 處理這段音訊。通過回傳 true;不通過時彈出提示對話框,使用者按「確定」
/// 關閉後回傳 false(中止流程,不會壓縮 / 上傳 / 呼叫後端)。
/// 找不到音檔或量不到長度時只檢查「是否已用完」,其餘交給後續流程處理。
Future<bool> ensureWithinUsageLimitForLyrics(
  BuildContext context,
  WidgetRef ref, {
  required String pathKey,
}) async {
  final audioPath = await ref.read(trackAudioResolverProvider).resolve(pathKey);
  final audioSeconds = audioPath == null
      ? null
      : await ref
            .read(audioDurationProbeProvider)
            .durationSeconds(pathKey: pathKey, audioPath: audioPath);

  final result = await ref
      .read(lyricsUsageLimitServiceProvider)
      .check(audioSeconds: audioSeconds);
  if (result is LyricsUsageOk) return true;
  if (!context.mounted) return false;

  logAnalyticsAction(LyricsAction.usageLimitReached);
  final l10n = AppLocalizations.of(context)!;
  final message = switch (result) {
    LyricsUsageInsufficient(:final remainingSeconds, :final audioSeconds) =>
      l10n.lyrics_usage_insufficient_for_audio(
        _ceilMinutes(audioSeconds),
        // 剩餘不足 1 分鐘時顯示 0,避免出現「剩 1 分鐘卻不夠 1 分鐘的歌」。
        remainingSeconds ~/ 60,
      ),
    _ => l10n.lyrics_usage_limit_reached,
  };
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.common_ok),
        ),
      ],
    ),
  );
  return false;
}

int _ceilMinutes(double seconds) => (seconds / 60).ceil();
