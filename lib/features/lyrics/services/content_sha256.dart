import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('seek_player/file_hash');

/// 音檔全檔內容的 SHA-256(64 碼小寫 hex),即曲目身份 trackId。
///
/// 與後端 `hashlib.sha256(file_bytes).hexdigest()` 同一個定義,送 AI 產生 /
/// 對時任務時當 `trackId` 附給後端(見後端 `_reuse_succeeded_task`)。
///
/// Android 走原生 `MessageDigest`(FileHashChannel,有硬體加速、在背景執行緒
/// 計算);沒有原生實作(測試、其他平台、背景 isolate)時改在 Dart isolate
/// 以 package:crypto 計算,結果相同。讀不到檔案回 null。
Future<String?> fileSha256(String path) async {
  try {
    return await _channel.invokeMethod<String>('sha256', {'path': path});
  } on MissingPluginException {
    return dartFileSha256(path);
  } on PlatformException {
    return null;
  }
}

/// 純 Dart 版的 [fileSha256](串流讀檔、在背景 isolate 計算)。
Future<String?> dartFileSha256(String path) async {
  try {
    return await Isolate.run(() async {
      final digest = await sha256.bind(File(path).openRead()).single;
      return digest.toString();
    });
  } catch (_) {
    return null;
  }
}

/// 送對時的歌詞行的 SHA-256(64 碼 hex):`sha256(utf8(lines.join("\n")))`。
///
/// [lines] 必須是實際送給後端的那份(已 trim、已濾掉空行),後端以同一套
/// 算法比對,同一首歌的歌詞內容一致才沿用對時結果。
String lyricsLinesSha256(List<String> lines) =>
    sha256.convert(utf8.encode(lines.join('\n'))).toString();
