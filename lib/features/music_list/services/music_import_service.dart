import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// iOS「匯入音樂」:以系統文件選擇器挑音訊檔,複製進 `Documents/Music/`,
/// 供 DocumentsMusicSource 掃描(方案 A,見 plans/23-ios-support.md)。
/// Android 走 MediaStore 掃描,不需匯入。
class MusicImportService {
  const MusicImportService();

  /// 開啟選擇器並匯入;回傳實際複製成功的檔案數(使用者取消回 0)。
  Future<int> importFromPicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return 0;

    final docs = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${docs.path}/Music');
    await musicDir.create(recursive: true);

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
