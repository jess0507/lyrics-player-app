import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seek_player/core/auth/auth_service.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';

/// 開 App 時把登入使用者的個人化設定與 App 版本單向記錄到 Firestore。
///
/// 於 App 根 widget watch 一次以註冊:建立當下即執行一次 [record]。
class UserRecordService {
  UserRecordService(
    this._ref, {
    required FirebaseFirestore firestore,
    required Future<PackageInfo> Function() loadPackageInfo,
  }) : _firestore = firestore,
       _loadPackageInfo = loadPackageInfo {
    unawaited(record());
  }

  final Ref _ref;
  final FirebaseFirestore _firestore;
  final Future<PackageInfo> Function() _loadPackageInfo;

  static const schemaVersion = 8;

  static const _userCollection = 'user';
  static const _settingCollection = 'setting';
  static const _settingDocId = '0';

  Future<void> record() async {
    if (!_ref.read(firebaseAvailableProvider)) {
      debugPrint('[UserRecord] Firebase 不可用,不記錄');
      return;
    }
    final uid = _ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      debugPrint('[UserRecord] 未登入,不記錄');
      return;
    }
    try {
      final info = await _loadPackageInfo();
      await _write(uid, info);
      debugPrint(
        '[UserRecord] 已記錄 uid=$uid app=${info.version}+${info.buildNumber}',
      );
    } catch (e, s) {
      reportError(e, s, reason: '記錄使用者設定失敗');
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore 寫入

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection(_userCollection).doc(uid);

  DocumentReference<Map<String, dynamic>> _settingDoc(String uid) =>
      _userDoc(uid).collection(_settingCollection).doc(_settingDocId);

  /// 主文件與設定文件一次 batch 寫入,避免只寫到一半;皆 merge 不動其他欄位。
  Future<void> _write(String uid, PackageInfo info) {
    final batch = _firestore.batch()
      ..set(_userDoc(uid), _userDocData(info), SetOptions(merge: true))
      ..set(_settingDoc(uid), _settingDocData(), SetOptions(merge: true));
    return batch.commit();
  }

  // ---------------------------------------------------------------------------
  // 文件內容

  Map<String, dynamic> _userDocData(PackageInfo info) => {
    'schemaVersion': schemaVersion,
    'appVersion': info.version,
    'buildNumber': info.buildNumber,
    'recordedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _settingDocData() => {
    ..._ref.read(settingsControllerProvider).toRemoteMap(),
    'settingUpdatedAt': FieldValue.serverTimestamp(),
  };
}

final userRecordServiceProvider = Provider<UserRecordService>(
  (ref) => UserRecordService(
    ref,
    firestore: FirebaseFirestore.instance,
    loadPackageInfo: PackageInfo.fromPlatform,
  ),
);
