import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:seek_player/core/update/open_play_store.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 後端回報此版本 App 已不支援(`upgrade_required`)時提示使用者更新。
///
/// Android 以 dialog 顯示並提供「前往商店更新」按鈕;其他平台沒有
/// Play 商店流程,只以 toast 顯示文字。
void showUpgradeRequiredPrompt(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  if (kIsWeb || !Platform.isAndroid) {
    showAppToast(l10n.lyrics_upgrade_required);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.lyrics_upgrade_required),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.update_later),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            openPlayStore();
          },
          child: Text(l10n.update_store_action),
        ),
      ],
    ),
  );
}
