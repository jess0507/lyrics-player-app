import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/app_locales.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';
import 'package:seek_player/shared/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile_settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settings_language),
            subtitle: Text(_localeLabel(settings.locale, l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/profile/settings/language'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settings_theme),
            subtitle: Text(_themeLabel(settings.themeMode, l10n)),
          ),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) controller.setThemeMode(mode);
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text(l10n.settings_theme_system),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text(l10n.settings_theme_light),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text(l10n.settings_theme_dark),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settings_color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final seed in AppColorSeed.values)
                  _ColorSwatch(
                    seed: seed,
                    selected: seed == settings.seedColor,
                    onTap: () => controller.setSeedColor(seed),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.gradient_outlined),
            title: Text(l10n.settings_gradient),
            subtitle: Text(l10n.settings_gradient_desc),
            value: settings.useGradient,
            onChanged: controller.setUseGradient,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            title: Text(l10n.settings_gradient_cover),
            subtitle: Text(l10n.settings_gradient_cover_desc),
            value: settings.gradientFromCover,
            // 僅在漸層開啟時可調整;關閉漸層時整列灰階停用。
            onChanged:
                settings.useGradient ? controller.setGradientFromCover : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.lyrics_outlined),
            title: Text(l10n.settings_auto_lyrics),
            subtitle: Text(l10n.settings_auto_lyrics_desc),
            value: settings.autoFullScreenLyrics,
            onChanged: controller.setAutoFullScreenLyrics,
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode, AppLocalizations l10n) => switch (mode) {
        ThemeMode.light => l10n.settings_theme_light,
        ThemeMode.dark => l10n.settings_theme_dark,
        ThemeMode.system => l10n.settings_theme_system,
      };

  String _localeLabel(Locale? locale, AppLocalizations l10n) {
    if (locale == null) return l10n.settings_language_system;
    for (final option in kAppLocales) {
      if (option.locale == locale) return option.nativeName;
    }
    return locale.toLanguageTag();
  }
}

/// 設定頁的單一主題色色塊；選中時顯示外圈與勾選圖示。
///
/// 單色(灰白)主題以斜分的半灰半白圓呈現,代表其隨亮度翻轉的特性。
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final AppColorSeed seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    final color = seed.color;
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: size / 2 + 4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: seed.isMono ? null : color,
            gradient: seed.isMono
                ? const LinearGradient(
                    colors: [
                      Color(0xFFE8EAED),
                      Color(0xFFE8EAED),
                      Color(0xFF5F6368),
                      Color(0xFF5F6368),
                    ],
                    stops: [0, 0.5, 0.5, 1],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  )
                : null,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  color: seed.isMono ||
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                      ? Colors.white
                      : Colors.black,
                )
              : null,
        ),
      ),
    );
  }
}
