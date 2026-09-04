import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/domain_backup.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

/// 個人化設定 ↔ `settings.json`(欄位即 `SettingsState.toRemoteMap()`)。
class SettingsBackup implements DomainBackup {
  SettingsBackup(this._ref);

  final Ref _ref;

  @override
  String get fileName => 'settings.json';

  @override
  String get label => 'settings';

  @override
  DateTime? get localModifiedAt =>
      _ref.read(syncStateStoreProvider).settingModifiedAt;

  @override
  Map<String, dynamic> encode() =>
      _ref.read(settingsControllerProvider).toRemoteMap();

  @override
  Future<void> restore(Map<String, dynamic> json) async {
    _ref
        .read(settingsControllerProvider.notifier)
        .restoreFromRemote(
          locale: json['locale'] as String?,
          themeMode: json['themeMode'] as String?,
          seedColor: json['seedColor'] as String?,
          useGradient: json['useGradient'] as bool?,
          gradientFromCover: json['gradientFromCover'] as bool?,
          playerDefaultTab: json['playerDefaultTab'] as String?,
          seekStepSeconds: (json['seekStepSeconds'] as num?)?.toInt(),
          // ignore: deprecated_member_use_from_same_package
          autoFullScreenLyrics: json['autoFullScreenLyrics'] as bool?,
        );
  }
}

final settingsBackupProvider = Provider<SettingsBackup>(
  (ref) => SettingsBackup(ref),
);
