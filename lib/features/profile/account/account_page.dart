import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/auth/auth_state_provider.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/profile/account/widgets/signed_out_view.dart';
import 'package:seek_player/features/profile/account/widgets/user_info_view.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final firebaseReady = ref.watch(firebaseAvailableProvider);
    if (!firebaseReady) {
      debugPrint('帳戶頁面:Firebase 不可用,帳戶功能停用');
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile_account)),
      body: !firebaseReady
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.account_unavailable,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ref
                .watch(authStateProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (user) => user == null
                      ? const SignInView()
                      : UserInfoView(user: user),
                ),
    );
  }
}
