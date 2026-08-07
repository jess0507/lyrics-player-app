import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:seek_player/core/permissions/permission_dialogs.dart';

/// 權限請求流程：先顯示自訂說明 Dialog（rationale），再呼叫系統權限請求，
/// 永久拒絕時引導使用者前往「應用程式設定」。
class PermissionService {
  const PermissionService();

  /// 確保已取得讀取本機音訊的權限。回傳是否已授權。
  Future<bool> ensureAudioPermission(BuildContext context) async {
    final permission = Permission.audio;
    var status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    if (!context.mounted) return false;
    final agreed = await showPermissionRationaleDialog(context);
    if (agreed != true) return false;

    status = await permission.request();
    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      final goSettings = await showOpenSettingsDialog(context);
      if (goSettings == true) await openAppSettings();
    }
    return false;
  }

  /// 通知列播放控制需要的通知權限（Android 13+）；失敗不阻擋播放。
  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }
}

const permissionService = PermissionService();
