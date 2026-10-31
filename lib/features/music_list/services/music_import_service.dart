import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// iOS「匯入音樂」:以系統文件選擇器挑音訊檔,複製進 `Documents/Music/`,
/// 供 DocumentsMusicSource 掃描(方案 A,見 plans/23-ios-support.md)。
/// Android 走 MediaStore 掃描,不需匯入;僅 [importFile] 會把單一檔案
/// 寫進公用 `Music/Seek Player/` 讓 MediaStore 收錄(原生端見
/// `MediaImportChannel.kt`)。
class MusicImportService {
  const MusicImportService();

  static const _channel = MethodChannel('seek_player/media_import');

  /// 開啟選擇器並匯入;回傳實際複製成功的檔案數(使用者取消回 0)。
  Future<int> importFromPicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return 0;

    final musicDir = await _documentsMusicDir();
    var imported = 0;
    for (final picked in result.files) {
      final source = picked.path;
      if (source == null) continue;
      try {
        await File(source).copy(_availablePath(musicDir.path, picked.name));
        imported++;
      } catch (_) {
        // 單檔複製失敗(來源消失/空間不足):跳過,不中斷整批匯入。
      }
    }
    return imported;
  }

  /// 把 [sourcePath] 匯入音樂庫掃描得到的位置,回傳匯入後的實體路徑;
  /// 失敗回 null。iOS 複製進 `Documents/Music/`;Android 交給 MediaStore。
  /// 匯入後需由呼叫端重掃音樂庫才會出現。
  Future<String?> importFile(String sourcePath, String fileName) async {
    try {
      if (Platform.isIOS) {
        final dest = _availablePath(
          (await _documentsMusicDir()).path,
          fileName,
        );
        await File(sourcePath).copy(dest);
        return dest;
      }
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

  static Future<Directory> _documentsMusicDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${docs.path}/Music');
    await musicDir.create(recursive: true);
    return musicDir;
  }

  /// 同名檔已存在時在副檔名前加 ` (n)`,避免覆蓋既有曲目。
  static String _availablePath(String dir, String fileName) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
    final ext = dot <= 0 ? '' : fileName.substring(dot);
    var candidate = '$dir/$fileName';
    var n = 1;
    while (File(candidate).existsSync()) {
      candidate = '$dir/$stem (${n++})$ext';
    }
    return candidate;
  }
}

final musicImportServiceProvider = Provider<MusicImportService>(
  (ref) => const MusicImportService(),
);
