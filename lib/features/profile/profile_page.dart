import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:seek_player/l10n/app_localizations.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = [
      (Icons.account_circle_outlined, l10n.profile_account, 'account'),
      (Icons.insights_outlined, l10n.profile_statistics, 'statistics'),
      (Icons.settings_outlined, l10n.profile_settings, 'settings'),
      (Icons.info_outline, l10n.profile_about, 'about'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tab_profile)),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final (icon, label, path) = entries[index];
          return ListTile(
            leading: Icon(icon),
            title: Text(label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/profile/$path'),
          );
        },
      ),
    );
  }
}
