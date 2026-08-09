import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/network/ensure_online.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';
import 'package:seek_player/features/profile/account/widgets/sync_now_button.dart';

/// 已登入:顯示頭像、Email、同步、登出與刪除帳號。
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

    return ListView(
      children: [
        const SizedBox(height: 16),
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
        const SizedBox(height: 32),
        const SyncNowButton(),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n.account_sign_out),
          onTap: () => _signOut(context, auth),
        ),
        const Divider(height: 1),
        const SizedBox(height: 32),
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
      ],
    );
  }

  /// 登出並以 toast 回報結果。成功後 authState 變更,本視圖會被換成
  /// 登入畫面;toast 掛在 root overlay,不依賴本視圖的 context。
  Future<void> _signOut(BuildContext context, AuthService auth) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await auth.signOut();
      showAppToast(l10n.account_signed_out);
    } catch (e, s) {
      reportError(e, s, reason: '登出失敗');
      showAppToast(l10n.account_sign_out_failed);
    }
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
    if (confirmed != true) return;
    try {
      await auth.deleteAccountData();
      showAppToast(l10n.account_delete_data_done);
    } on FirebaseFunctionsException catch (e, s) {
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
    if (confirmed != true) return;
    try {
      await auth.deleteAccount();
    } on FirebaseFunctionsException catch (e, s) {
      reportError(e, s, reason: 'delete_account 失敗（code=${e.code}）');
      showAppToast(l10n.account_operation_failed);
    } on FirebaseAuthException catch (e, s) {
      reportError(e, s, reason: '刪除帳號後登出失敗（code=${e.code}）');
      showAppToast(l10n.account_operation_failed);
    }
  }
}
