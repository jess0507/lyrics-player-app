import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// 把單一音訊檔寫進公用 `Music/Seek Player/` 讓 MediaStore 收錄
/// (原生端見 `MediaImportChannel.kt`);音樂庫走 MediaStore 掃描,
/// 平常不需匯入,只有工具頁選檔對不上曲庫時才用到。
class MusicImportService {
  const MusicImportService();

  static const _channel = MethodChannel('seek_player/media_import');

  /// 把 [sourcePath] 匯入音樂庫掃描得到的位置,回傳匯入後的實體路徑;
  /// 失敗回 null。
  /// 匯入後需由呼叫端重掃音樂庫才會出現。
  Future<String?> importFile(String sourcePath, String fileName) async {
    try {
      // API 24–28 直接寫公用目錄需 WRITE_EXTERNAL_STORAGE;29+ 不需權限,
      // 請求結果一律忽略,寫入失敗由原生端回 null。
      await Permission.storage.request();
      return await _channel.invokeMethod<String>('importAudio', {
        'path': sourcePath,
        'displayName': fileName,
      });
    } catch (_) {
      return null;
    }
  }
}

final musicImportServiceProvider = Provider<MusicImportService>(
  (ref) => const MusicImportService(),
);
