import 'package:flutter/widgets.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 登出並以 toast 回報結果。toast 掛在 root overlay,
/// 成功後呼叫端 widget 因 authState 變更被移除也不影響。
Future<void> signOutWithToast(BuildContext context, AuthService auth) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    await auth.signOut();
    logAnalyticsAction(AccountAction.signOut, result: AnalyticsResult.success);
    showAppToast(l10n.account_signed_out);
  } catch (e, s) {
    logAnalyticsAction(AccountAction.signOut, result: AnalyticsResult.failure);
    reportError(e, s, reason: '登出失敗');
    showAppToast(l10n.account_sign_out_failed);
  }
}
