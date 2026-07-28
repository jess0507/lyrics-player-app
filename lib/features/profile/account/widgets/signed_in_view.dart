import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/crash_reporter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import 'sync_now_button.dart';

/// 已登入:顯示頭像、Email、同步、登出與刪除帳號。
class UserInfoView extends ConsumerWidget {
  const UserInfoView({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.read(authServiceProvider);
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
          onTap: () => auth.signOut(),
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

  Future<void> _confirmDeleteData(
    BuildContext context,
    AuthService auth,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showAppSnackBar(l10n.account_delete_data_done);
    } on FirebaseFunctionsException catch (e, s) {
      reportError(e, s, reason: 'delete_account_data 失敗（code=${e.code}）');
      messenger.showAppSnackBar(l10n.account_operation_failed);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AuthService auth) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showAppSnackBar(l10n.account_operation_failed);
    } on FirebaseAuthException catch (e, s) {
      reportError(e, s, reason: '刪除帳號後登出失敗（code=${e.code}）');
      messenger.showAppSnackBar(l10n.account_operation_failed);
    }
  }
}
