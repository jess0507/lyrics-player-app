import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../lyrics/usage_limit/lyrics_usage_limit_service.dart';

/// 雲端歌詞功能(自動產生 / 自動對時)執行前的用量關卡。
///
/// 本月免費用量未達上限回傳 true;已達上限時彈出提示對話框,使用者按
/// 「確定」關閉後回傳 false(中止流程,不會呼叫後端上傳/辨識)。
Future<bool> ensureWithinUsageLimitForLyrics(
  BuildContext context,
  WidgetRef ref,
) async {
  final reached = await ref
      .read(lyricsUsageLimitServiceProvider)
      .isMonthlyLimitReached();
  if (!reached) return true;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.lyrics_usage_limit_reached),
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
