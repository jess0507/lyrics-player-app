import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/app_locales.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(
      settingsControllerProvider.select((s) => s.locale),
    );
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_language)),
      body: RadioGroup<Locale?>(
        groupValue: current,
        onChanged: controller.setLocale,
        child: ListView(
          children: [
            RadioListTile<Locale?>(
              value: null,
              title: Text(l10n.settings_language_system),
            ),
            for (final option in kAppLocales)
              RadioListTile<Locale?>(
                value: option.locale,
                title: Text(option.nativeName),
              ),
          ],
        ),
      ),
    );
  }
}
