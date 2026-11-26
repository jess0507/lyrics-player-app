import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/auth/auth_state_provider.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/features/profile/account/sign_out_action.dart';
import 'package:seek_player/features/profile/widgets/profile_card.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「更多」頁底部的登出卡片,與上方項目共用 [ProfileCard] 外觀。
/// Firebase 不可用或未登入時不顯示。
class SignOutCard extends ConsumerWidget {
  const SignOutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(firebaseAvailableProvider)) return const SizedBox.shrink();
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return ProfileCard(
      children: [
        ListTile(
          title: Text(l10n.account_sign_out),
          onTap: () => signOutWithToast(context, ref.read(authServiceProvider)),
        ),
      ],
    );
  }
}
