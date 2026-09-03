import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/storage/preferences_service.dart';

/// 「更多 → 重置」:清空 app 自己產生的資料,不碰使用者的音樂等多媒體檔案。
///
/// Android:交給系統 `ActivityManager.clearApplicationUserData()`,效果等同
/// 「應用程式資訊 → 儲存空間 → 清除資料」,整個沙盒清空後 process 立刻被
/// 終止,下次開啟等於全新安裝(Android 音樂走 MediaStore,沙盒內沒有
/// 使用者的多媒體檔案)。系統呼叫失敗才退回手動清除。
///
/// iOS(及手動清除):
/// - Isar 全部 collection(統計、歌詞、播放清單、封面、指紋、metadata)
/// - SharedPreferences(設定、同步時戳、待處理清單等)
/// - `covers/` 目錄(自訂封面匯入時複製進 app 沙盒的圖檔;原圖仍在相簿)
/// 匯入到 `Documents/Music/` 的音訊檔保留;清完後由呼叫端重啟 app,
/// 讓記憶體內的 provider 狀態一併歸零。
class AppDataResetService {
  AppDataResetService(this._ref);

  final Ref _ref;

  static const _channel = MethodChannel('seek_player/app_data');

  /// 回傳 true 表示已交由系統清除(實務上 process 會直接被終止,
  /// 呼叫端不會等到回傳);false 表示走手動清除,呼叫端需自行重啟。
  Future<bool> reset() async {
    if (Platform.isAndroid) {
      final cleared = await _channel.invokeMethod<bool>('clear') ?? false;
      if (cleared) return true;
    }
    await _clearManually();
    return false;
  }

  Future<void> _clearManually() async {
    final isar = _ref.read(isarProvider);
    await isar.writeTxn(() => isar.clear());
    await _ref.read(preferencesServiceProvider).clear();
    final docs = await getApplicationDocumentsDirectory();
    final covers = Directory('${docs.path}/covers');
    if (covers.existsSync()) await covers.delete(recursive: true);
  }
}

final appDataResetServiceProvider = Provider<AppDataResetService>(
  AppDataResetService.new,
);
