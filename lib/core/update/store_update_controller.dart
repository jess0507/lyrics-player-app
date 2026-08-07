import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

import 'package:seek_player/core/crash_reporter.dart';

/// Google Play 商店版本檢查的狀態。
enum StoreUpdateState {
  idle,
  checking,

  /// Play 上有較新的正式版,UI 應詢問使用者是否前往更新。
  updateAvailable,
  upToDate,
  error,
}

/// App 啟動與每次 resume 時,向 Google Play 查詢是否有較新的版本。
///
/// 以官方 In-App Update API(Play Core)查詢,只用來偵測新版本,
/// 實際更新交由 Google Play 商店頁面。僅 Android 有效;
/// 非 Play 安裝(debug / sideload)查詢會丟例外,安靜忽略即可。
/// 每次檢查都先經過 [StoreUpdateState.checking],確保重複偵測到
/// 新版本時監聽端仍會收到狀態轉變。
class StoreUpdateController extends Notifier<StoreUpdateState> {
  AppLifecycleListener? _lifecycleListener;

  @override
  StoreUpdateState build() {
    if (kIsWeb || !Platform.isAndroid) return StoreUpdateState.idle;
    // 等第一幀渲染完成後才開始,確保啟動畫面與首頁繪製不受影響。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _check();
    });
    _lifecycleListener = AppLifecycleListener(onResume: _check);
    ref.onDispose(() => _lifecycleListener?.dispose());
    return StoreUpdateState.idle;
  }

  Future<void> _check() async {
    if (state == StoreUpdateState.checking) return;
    state = StoreUpdateState.checking;
    try {
      final info = await InAppUpdate.checkForUpdate();
      state = info.updateAvailability == UpdateAvailability.updateAvailable
          ? StoreUpdateState.updateAvailable
          : StoreUpdateState.upToDate;
    } catch (e, s) {
      debugPrint('Google Play 版本檢查失敗：$e');
      reportError(e, s, reason: 'Google Play 版本檢查失敗');
      state = StoreUpdateState.error;
    }
  }
}

final storeUpdateControllerProvider =
    NotifierProvider<StoreUpdateController, StoreUpdateState>(
      StoreUpdateController.new,
    );
