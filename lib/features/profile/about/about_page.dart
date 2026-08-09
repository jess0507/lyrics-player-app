import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/profile/about/providers/app_version_provider.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  // 官網(seek-player-privacy-policy repo 部署至 Firebase Hosting)的政策頁。
  static final _privacyPolicyUrl = Uri.parse(
    'https://seek-player-f724e.web.app/privacy-policy',
  );

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(_privacyPolicyUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider).valueOrNull ?? '';
    // logo 的橫線在淺色版是黑色、深色版是白色（綠色音符兩版相同）。
    // 背景透明直接疊在 Scaffold 上，深色模式沿用淺色版會讓橫線幾乎看不見。
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile_about)),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.transparent,
              backgroundImage:
                  (isDark ? Assets.icon.appLogoDark : Assets.icon.appLogoPng)
                      .provider(),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              l10n.app_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.tag),
            title: Text(l10n.about_version),
            trailing: Text(version),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.about_privacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openPrivacyPolicy,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.about_licenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.app_title,
              applicationVersion: version,
            ),
          ),
        ],
      ),
    );
  }
}
