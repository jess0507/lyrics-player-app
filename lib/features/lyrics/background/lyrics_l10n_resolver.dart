import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/settings_controller.dart';

/// 依 app 設定(未設則系統語系)解析 l10n;不支援的語系回退英文。供背景歌詞
/// 流程共用——這些呼叫端(controller / `LyricsPendingSyncService`)本身不是
/// widget,無法用 `AppLocalizations.of(context)`。
AppLocalizations resolveLyricsL10n(Ref ref) {
  final locale =
      ref.read(settingsControllerProvider).locale ?? PlatformDispatcher.instance.locale;
  try {
    return lookupAppLocalizations(locale);
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}
