import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/profile/widgets/profile_entry.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_logo_leading.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const entries = ProfileEntry.values;

    return Scaffold(
      appBar: AppBar(
        // 分頁根頁沒有返回鍵,左側改放 app 圖示。
        leading: const AppLogoLeading(),
        title: Text(l10n.tab_profile),
      ),
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
