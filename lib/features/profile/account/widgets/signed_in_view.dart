import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/crash_reporter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../providers/last_sync_at_provider.dart';
import 'sync_now_button.dart';

/// 已登入:顯示頭像、Email、登出與刪除帳號。
class UserInfoView extends ConsumerWidget {
  const UserInfoView({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.read(authServiceProvider);
    final photo = user.photoURL;
    final lastSyncAt = ref.watch(lastSyncAtProvider);

    return Column(
      children: [
        const SizedBox(height: 16),
        Center(
          child: CircleAvatar(
            radius: 48,
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
        const SizedBox(height: 8),
        Center(
          child: Text(
            lastSyncAt == null
                ? l10n.account_never_synced
                : l10n.account_last_synced(
                    DateFormat.yMd(
                      Localizations.localeOf(context).toString(),
                    ).add_Hm().format(lastSyncAt),
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Center(child: SyncNowButton()),
        const SizedBox(height: 32),
        FilledButton.tonalIcon(
          onPressed: () => auth.signOut(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.account_sign_out),
        ),
        Spacer(),
        TextButton.icon(
          onPressed: () => _confirmDeleteData(context, auth),
          icon: const Icon(Icons.cleaning_services_outlined),
          label: Text(l10n.account_delete_data),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _confirmDelete(context, auth),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.account_delete),
        ),
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
