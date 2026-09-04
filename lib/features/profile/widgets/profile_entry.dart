import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:seek_player/features/profile/feedback/send_feedback_action.dart';
import 'package:seek_player/features/profile/reset/reset_app_action.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「更多」頁的每一列:icon、標籤與點擊行為都集中在這裡,
/// 頁面本身只負責依序畫成 ListTile。
enum ProfileEntry {
  account(Icons.account_circle_outlined, path: 'account'),
  backup(Icons.cloud_upload_outlined, path: 'backup'),
  statistics(Icons.insights_outlined, path: 'statistics'),
  settings(Icons.settings_outlined, path: 'settings'),
  about(Icons.info_outline, path: 'about'),
  reset(Icons.restart_alt),
  feedback(Icons.mail_outline);

  const ProfileEntry(this.icon, {this.path});

  final IconData icon;

  /// 導頁目標(`/profile/<path>`);null 代表點擊執行動作而非導頁。
  final String? path;

  bool get navigates => path != null;

  String label(AppLocalizations l10n) => switch (this) {
    account => l10n.profile_account,
    backup => l10n.profile_backup,
    statistics => l10n.profile_statistics,
    settings => l10n.profile_settings,
    about => l10n.profile_about,
    reset => l10n.profile_reset,
    feedback => l10n.profile_feedback,
  };

  Future<void> onTap(BuildContext context, WidgetRef ref) async {
    switch (this) {
      // 備份走 Google Drive 授權,與帳戶登入無關(plan 26),直接進頁。
      case account || backup || statistics || settings || about:
        context.go('/profile/$path');
      case reset:
        await confirmAndResetApp(context, ref);
      case feedback:
        await sendFeedback(context);
    }
  }
}
