import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/network/ensure_online.dart';
import 'package:seek_player/features/profile/backup/widgets/backup_section.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 已登入:最上方是頭像、名稱與 Email,接著是備份區塊(Google Drive 連結、
/// 上次備份),最後是刪除資料/刪除帳號(登出在「更多」頁)。備份授權與 Firebase 登入彼此獨立(plan 26)。
class UserInfoView extends ConsumerStatefulWidget {
  const UserInfoView({super.key, required this.user});

  final User user;

  @override
  ConsumerState<UserInfoView> createState() => _UserInfoViewState();
}

class _UserInfoViewState extends ConsumerState<UserInfoView> {
  @override
  void initState() {
    super.initState();
    // 進入本頁就探一次網路:離線時送出離線事件,由 OfflineToastListener
    // 顯示提示,各動作本身不再各自守門。
    unawaited(ensureOnline(ref));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.read(authServiceProvider);
    final user = widget.user;
    final photo = user.photoURL;

    return Column(
      children: [
        // 使用者資訊
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null ? const Icon(Icons.person, size: 48) : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            user.displayName ??
                user.email ??
                user.phoneNumber ??
                l10n.account_guest,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (user.email != null) ...[
          const SizedBox(height: 4),
          Center(child: Text(user.email!)),
        ],
        const SizedBox(height: 24),
        // 備份
        const Divider(height: 1),
        const BackupSection(),
        const Spacer(),
        // 危險操作
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(l10n.account_delete_data),
          onTap: () => _confirmDeleteData(context, auth),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            l10n.account_delete,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () => _confirmDelete(context, auth),
        ),
        const Divider(height: 1),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _confirmDeleteData(
    BuildContext context,
    AuthService auth,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.account_delete_data),
        content: Text(l10n.account_delete_data_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      logAnalyticsAction(
        AccountAction.deleteData,
        result: AnalyticsResult.cancelled,
      );
      return;
    }
    try {
      await auth.deleteAccountData();
      logAnalyticsAction(
        AccountAction.deleteData,
        result: AnalyticsResult.success,
      );
      showAppToast(l10n.account_delete_data_done);
    } on FirebaseFunctionsException catch (e, s) {
      logAnalyticsAction(
        AccountAction.deleteData,
        result: AnalyticsResult.failure,
      );
      reportError(e, s, reason: 'delete_account_data 失敗（code=${e.code}）');
      showAppToast(l10n.account_operation_failed);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AuthService auth) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.account_delete),
        content: Text(l10n.account_delete_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      logAnalyticsAction(
        AccountAction.deleteAccount,
        result: AnalyticsResult.cancelled,
      );
      return;
    }
    try {
      await auth.deleteAccount();
      logAnalyticsAction(
        AccountAction.deleteAccount,
        result: AnalyticsResult.success,
      );
    } on FirebaseFunctionsException catch (e, s) {
      logAnalyticsAction(
        AccountAction.deleteAccount,
        result: AnalyticsResult.failure,
      );
      reportError(e, s, reason: 'delete_account 失敗（code=${e.code}）');
      showAppToast(l10n.account_operation_failed);
    } on FirebaseAuthException catch (e, s) {
      logAnalyticsAction(
        AccountAction.deleteAccount,
        result: AnalyticsResult.failure,
      );
      reportError(e, s, reason: '刪除帳號後登出失敗（code=${e.code}）');
      showAppToast(l10n.account_operation_failed);
    }
  }
}
