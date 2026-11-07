import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// 音檔全檔內容的 SHA-256(64 碼 hex)。
///
/// 送出 AI 產生 / 對時任務時當 `trackId` 附給後端,讓後端判斷同一首歌是否
/// 處理過、可直接沿用結果(見後端 `functions/main.py` 的
/// `_reuse_succeeded_task`)。以串流方式讀檔,在背景 isolate 執行;讀不到檔案
/// 回 null(後端就照常派工、不查快取)。
Future<String?> fileSha256(String path) async {
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
