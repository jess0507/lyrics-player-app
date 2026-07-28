import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/preferences_service.dart';
import '../../core/sync/sync_state_store.dart';
import '../theme/app_theme.dart';

/// 應用程式偏好：語言、主題模式與主題色（持久化於 SharedPreferences）。
class SettingsState {
  const SettingsState({
    this.locale,
    this.themeMode = ThemeMode.system,
    this.seedColor = AppColorSeed.defaultSeed,
    this.useGradient = true,
    this.gradientFromCover = true,
    this.autoFullScreenLyrics = false,
  });

  /// null 代表「跟隨系統語言」。
  final Locale? locale;
  final ThemeMode themeMode;
  final AppColorSeed seedColor;

  /// 是否在播放頁等處套用主題色漸層背景。
  final bool useGradient;

  /// 漸層是否改用目前曲目封面的主色(僅在 [useGradient] 開啟時生效)。
  final bool gradientFromCover;

  /// 進入播放頁時,若曲目有歌詞則自動切到滿版歌詞模式。
  final bool autoFullScreenLyrics;

  SettingsState copyWith({
    Object? locale = _sentinel,
    ThemeMode? themeMode,
    AppColorSeed? seedColor,
    bool? useGradient,
    bool? gradientFromCover,
    bool? autoFullScreenLyrics,
  }) {
    return SettingsState(
      locale: identical(locale, _sentinel) ? this.locale : locale as Locale?,
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      useGradient: useGradient ?? this.useGradient,
      gradientFromCover: gradientFromCover ?? this.gradientFromCover,
      autoFullScreenLyrics: autoFullScreenLyrics ?? this.autoFullScreenLyrics,
    );
  }

  /// 雲端同步（Firestore `user/{uid}.settings`）的欄位表示。
  Map<String, dynamic> toRemoteMap() => {
    'locale': locale == null ? null : SettingsController._encodeLocale(locale!),
    'themeMode': themeMode.name,
    'seedColor': seedColor.name,
    'useGradient': useGradient,
    'gradientFromCover': gradientFromCover,
    'autoFullScreenLyrics': autoFullScreenLyrics,
  };

  static const Object _sentinel = Object();
}

class SettingsController extends Notifier<SettingsState> {
  static const _kLocale = 'settings.locale';
  static const _kThemeMode = 'settings.themeMode';
  static const _kSeedColor = 'settings.seedColor';
  static const _kUseGradient = 'settings.useGradient';
  static const _kGradientFromCover = 'settings.gradientFromCover';
  static const _kAutoFullScreenLyrics = 'settings.autoFullScreenLyrics';

  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  SettingsState build() {
    return SettingsState(
      locale: _decodeLocale(_prefs.getString(_kLocale)),
      themeMode: _decodeThemeMode(_prefs.getString(_kThemeMode)),
      seedColor: AppColorSeed.fromName(_prefs.getString(_kSeedColor)),
      useGradient: _prefs.getBool(_kUseGradient) ?? true,
      gradientFromCover: _prefs.getBool(_kGradientFromCover) ?? true,
      autoFullScreenLyrics: _prefs.getBool(_kAutoFullScreenLyrics) ?? false,
    );
  }

  void setLocale(Locale? locale) {
    state = state.copyWith(locale: locale);
    if (locale == null) {
      _prefs.remove(_kLocale);
    } else {
      _prefs.setString(_kLocale, _encodeLocale(locale));
    }
    _markModified();
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString(_kThemeMode, mode.name);
    _markModified();
  }

  void setSeedColor(AppColorSeed seed) {
    state = state.copyWith(seedColor: seed);
    _prefs.setString(_kSeedColor, seed.name);
    _markModified();
  }

  void setUseGradient(bool value) {
    state = state.copyWith(useGradient: value);
    _prefs.setBool(_kUseGradient, value);
    _markModified();
  }

  void setGradientFromCover(bool value) {
    state = state.copyWith(gradientFromCover: value);
    _prefs.setBool(_kGradientFromCover, value);
    _markModified();
  }

  void setAutoFullScreenLyrics(bool value) {
    state = state.copyWith(autoFullScreenLyrics: value);
    _prefs.setBool(_kAutoFullScreenLyrics, value);
    _markModified();
  }

  /// 還原雲端備份的設定（套用並落地 prefs）。
  ///
  /// 讀取容錯：缺欄位 / 未知值 fallback 預設。還原不算本機變更，
  /// 不更新 lastModifiedAt，避免還原後馬上又觸發上傳。
  void restoreFromRemote({
    String? locale,
    String? themeMode,
    String? seedColor,
    bool? useGradient,
    bool? gradientFromCover,
    bool? autoFullScreenLyrics,
  }) {
    state = SettingsState(
      locale: _decodeLocale(locale),
      themeMode: _decodeThemeMode(themeMode),
      seedColor: AppColorSeed.fromName(seedColor),
      useGradient: useGradient ?? true,
      gradientFromCover: gradientFromCover ?? true,
      autoFullScreenLyrics: autoFullScreenLyrics ?? false,
    );
    final restored = state.locale;
    if (restored == null) {
      _prefs.remove(_kLocale);
    } else {
      _prefs.setString(_kLocale, _encodeLocale(restored));
    }
    _prefs.setString(_kThemeMode, state.themeMode.name);
    _prefs.setString(_kSeedColor, state.seedColor.name);
    _prefs.setBool(_kUseGradient, state.useGradient);
    _prefs.setBool(_kGradientFromCover, state.gradientFromCover);
    _prefs.setBool(_kAutoFullScreenLyrics, state.autoFullScreenLyrics);
  }

  void _markModified() =>
      ref.read(syncStateStoreProvider).markSettingModified();

  static String _encodeLocale(Locale locale) {
    return locale.countryCode == null
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
  }

  static Locale? _decodeLocale(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('_');
    return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  static ThemeMode _decodeThemeMode(String? value) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
