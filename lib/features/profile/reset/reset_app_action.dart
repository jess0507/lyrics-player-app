import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart';

import 'package:seek_player/features/profile/reset/app_data_reset_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 重置前先跳確認 dialog;確認後清空 app 資料。Android 由系統清除並
/// 直接終止 process(見 AppDataResetService),失敗退回手動清除再重啟;
/// iOS 無法程式化重啟,改提示使用者手動重開。
Future<void> confirmAndResetApp(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.profile_reset_title),
      content: Text(l10n.profile_reset_message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.common_confirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final clearedBySystem = await ref.read(appDataResetServiceProvider).reset();
  if (clearedBySystem) return;
  if (Platform.isAndroid) {
    await Restart.restartApp(mode: RestartMode.process);
  } else {
    showAppToast(l10n.profile_reset_restart_hint);
  }
}
