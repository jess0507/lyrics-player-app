import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
/// 實際更新交由 Google Play 商店頁面。僅 Android 有效。
/// 檢查失敗一律上報 Crashlytics,reason 會帶上判讀後的原因
/// (找不到 Play 商店、非 Play 安裝、Play 商店行程中斷等),
/// 方便在 console 決定哪些可以忽略;下次 resume 會自動重查。
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
    } on PlatformException catch (e, s) {
      reportError(
        e,
        s,
        reason: 'Google Play 版本檢查失敗:${_describeFailure(e)}',
      );
      state = StoreUpdateState.error;
    } catch (e, s) {
      reportError(e, s, reason: 'Google Play 版本檢查失敗');
      state = StoreUpdateState.error;
    }
  }
}

/// Play Core `InstallErrorCode` 對應的說明;
/// in_app_update 會把它包在訊息裡,形式為 `Install Error(-9): ...`。
const _installErrorDescriptions = <int, String>{
  -2: '未知錯誤(ERROR_UNKNOWN)',
  -3: '此裝置不支援 In-App Update API(ERROR_API_NOT_AVAILABLE)',
  -4: '請求無效(ERROR_INVALID_REQUEST)',
  -5: '此使用者或裝置無法安裝更新(ERROR_INSTALL_UNAVAILABLE)',
  -6: '裝置狀態不允許更新,如電量或儲存空間不足(ERROR_INSTALL_NOT_ALLOWED)',
  -7: '更新尚未下載(ERROR_DOWNLOAD_NOT_PRESENT)',
  -8: '已有更新正在進行(ERROR_INSTALL_IN_PROGRESS)',
  -9: '找不到 Google Play 商店(ERROR_PLAY_STORE_NOT_FOUND)',
  -10: '非從 Google Play 安裝,或該帳號未擁有此 app(ERROR_APP_NOT_OWNED)',
  -100: 'Google Play 內部錯誤(ERROR_INTERNAL_ERROR)',
};

final _installErrorPattern = RegExp(r'Install Error\((-?\d+)\)');

/// 把 in_app_update 丟出的例外判讀成看得懂的失敗原因,給 Crashlytics 的 reason 用。
String _describeFailure(PlatformException e) {
  final message = e.message ?? '';
  final match = _installErrorPattern.firstMatch(message);
  if (match != null) {
    final code = int.parse(match.group(1)!);
    return _installErrorDescriptions[code] ?? '未列出的 Play Core 錯誤碼 $code';
  }
  if (message.contains('Binder has died')) {
    return 'Google Play 商店行程在查詢途中中斷(Binder has died)';
  }
  return '未分類(${e.code})';
}

final storeUpdateControllerProvider =
    NotifierProvider<StoreUpdateController, StoreUpdateState>(
      StoreUpdateController.new,
    );
