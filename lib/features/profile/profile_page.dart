import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restart_app/restart_app.dart';

import 'package:seek_player/features/profile/reset/app_data_reset_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 「更多」頁的每一列:icon、標籤與點擊行為都集中在這裡,
/// 頁面本身只負責依序畫成 ListTile。
enum _ProfileEntry {
  account(Icons.account_circle_outlined, path: 'account'),
  statistics(Icons.insights_outlined, path: 'statistics'),
  settings(Icons.settings_outlined, path: 'settings'),
  about(Icons.info_outline, path: 'about'),
  reset(Icons.restart_alt);

  const _ProfileEntry(this.icon, {this.path});

  final IconData icon;

  /// 導頁目標(`/profile/<path>`);null 代表點擊執行動作而非導頁。
  final String? path;

  bool get navigates => path != null;

  String label(AppLocalizations l10n) => switch (this) {
    account => l10n.profile_account,
    statistics => l10n.profile_statistics,
    settings => l10n.profile_settings,
    about => l10n.profile_about,
    reset => l10n.profile_reset,
  };

  Future<void> onTap(BuildContext context, WidgetRef ref) async {
    switch (this) {
      case account || statistics || settings || about:
        context.go('/profile/$path');
      case reset:
        await _confirmReset(context, ref);
    }
  }
}

/// 重置前先跳確認 dialog;確認後清空 app 資料。Android 由系統清除並
/// 直接終止 process(見 AppDataResetService),失敗退回手動清除再重啟;
/// iOS 無法程式化重啟,改提示使用者手動重開。
Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
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

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const entries = _ProfileEntry.values;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tab_profile)),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            leading: Icon(entry.icon),
            title: Text(entry.label(l10n)),
            trailing: entry.navigates ? const Icon(Icons.chevron_right) : null,
            onTap: () => entry.onTap(context, ref),
          );
        },
      ),
    );
  }
}
