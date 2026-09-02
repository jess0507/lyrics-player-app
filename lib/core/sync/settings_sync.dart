import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

/// 單一文件 `setting/0`的推送與還原
class SettingsSync {
  SettingsSync(this._ref);

  final Ref _ref;

  static const _docId = '0';

  DocumentReference<Map<String, dynamic>> _doc(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) => userDoc.collection('setting').doc(_docId);

  /// 覆寫 `setting/0` 文件裡設定本身的欄位（merge，不動時戳欄位）。
  Future<void> push(DocumentReference<Map<String, dynamic>> userDoc) =>
      _doc(userDoc).set(
        _ref.read(settingsControllerProvider).toRemoteMap(),
        SetOptions(merge: true),
      );

  /// 以 `setting/0` 文件還原本機設定；文件不存在時不動本機。
  Future<void> restore(DocumentReference<Map<String, dynamic>> userDoc) async {
    final raw = (await _doc(userDoc).get()).data();
    if (raw == null) return;
    _ref
        .read(settingsControllerProvider.notifier)
        .restoreFromRemote(
          locale: raw['locale'] as String?,
          themeMode: raw['themeMode'] as String?,
          seedColor: raw['seedColor'] as String?,
          useGradient: raw['useGradient'] as bool?,
          gradientFromCover: raw['gradientFromCover'] as bool?,
          playerDefaultTab: raw['playerDefaultTab'] as String?,
          // Firestore 數值可能以 double 回傳,統一轉 int。
          seekStepSeconds: (raw['seekStepSeconds'] as num?)?.toInt(),
          // ignore: deprecated_member_use_from_same_package
          autoFullScreenLyrics: raw['autoFullScreenLyrics'] as bool?,
        );
  }
}

final settingsSyncProvider = Provider<SettingsSync>((ref) => SettingsSync(ref));
