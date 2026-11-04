import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// 頭 / 尾各取的位元組數。
const _chunkSize = 64 * 1024;

/// 音檔內容指紋:`sha1("{size}:" + 頭 64KB + 尾 64KB)` 的 40 碼 hex。
///
/// 送出 AI 產生 / 對時任務時附給後端,讓後端判斷同一首歌是否處理過、可直接
/// 沿用結果(見後端 `functions/main.py` 的 `_lookup_cached_job`)。與舊版
/// pathKey 同一套演算法,後端也能沿用舊版以指紋為文件 id 的結果。
///
/// 只讀頭尾,大檔也只讀 128KB;在背景 isolate 執行。讀不到檔案回 null
/// (後端就照常派工、不查快取)。
Future<String?> audioFingerprint(String path) async {
  try {
    return await Isolate.run(() => _hash(path));
  } catch (_) {
    return null;
  }
}

Future<String> _hash(String path) async {
  final file = await File(path).open();
  try {
    final size = await file.length();
    Digest? digest;
    final input = sha1.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((d) => digest = d.single),
    );
    input.add('$size:'.codeUnits);
    input.add(await file.read(_chunkSize));
    // 檔案大於兩個 chunk 才另取尾段,避免與頭段重疊重複計算。
    if (size > _chunkSize * 2) {
      await file.setPosition(size - _chunkSize);
      input.add(await file.read(_chunkSize));
    }
    input.close();
    return digest!.toString();
  } finally {
    await file.close();
  }
}
