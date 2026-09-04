import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/sync/drive_link_state.dart';
import 'package:seek_player/core/sync/google_drive_account.dart';

/// Google Drive 備份連結狀態的單一來源:備份頁 watch 它畫 UI,
/// SyncService watch 它決定何時同步(見 SyncService._init)。
///
/// 初始狀態依 prefs 判斷:曾連結者先給 [DriveNeedsRelink],待
/// [restoreSession] 取回 session 後才轉 [DriveLinked];避免 UI 在 session
/// 尚未確認時就顯示「已連結」。
class DriveLinkController extends Notifier<DriveLinkState> {
  GoogleDriveAccount get _account => ref.read(googleDriveAccountProvider);

  @override
  DriveLinkState build() {
    final account = _account;
    if (!account.isLinked) return const DriveNotLinked();
    if (account.hasSession) return DriveLinked(account.linkedEmail ?? '');
    return DriveNeedsRelink(account.linkedEmail);
  }

  /// App 啟動時由 SyncService 呼叫:嘗試取回 session,回傳是否可同步。
  Future<bool> restoreSession() async {
    if (!_account.isLinked) return false;
    final ok = await _account.restoreSession();
    state = ok
        ? DriveLinked(_account.linkedEmail ?? '')
        : DriveNeedsRelink(_account.linkedEmail);
    if (!ok) debugPrint('[Drive] 取不回 Google session,需重新連結');
    return ok;
  }

  /// 使用者按「連結 / 重新連結」。成功回傳 true;取消或拒絕授權回 false
  /// 且狀態不變;其他錯誤上報後回 false。
  Future<bool> link() async {
    try {
      final email = await _account.link();
      if (email == null) return false;
      state = DriveLinked(email);
      return true;
    } catch (e, s) {
      reportError(e, s, reason: 'Google Drive 連結失敗');
      return false;
    }
  }

  /// 使用者按「解除連結」。
  Future<void> unlink() async {
    await _account.unlink();
    state = const DriveNotLinked();
  }

  /// Drive API 回 401 / 403(scope 被撤銷)時由 SyncService 呼叫。
  void markNeedsRelink() {
    if (state is! DriveLinked) return;
    state = DriveNeedsRelink(_account.linkedEmail);
  }
}

final driveLinkStateProvider =
    NotifierProvider<DriveLinkController, DriveLinkState>(
      DriveLinkController.new,
    );
