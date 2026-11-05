import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// 頭 / 尾各取的位元組數。
const _chunkSize = 64 * 1024;

/// 音檔內容指紋:`sha1("{size}:" + 頭 64KB + 尾 64KB)` 的 40 碼 hex。
///
/// **已停用**:送 AI 產生 / 對時任務時改帶全檔 MD5(`trackMd5`,見
/// `fileMd5` / `TrackMd5Service`),後端不再比對 `fingerprint`。僅保留演算法
/// 供參考舊任務文件上的 `fingerprint` 欄位,新程式碼不要使用。
///
/// 只讀頭尾,大檔也只讀 128KB;在背景 isolate 執行。讀不到檔案回 null。
@Deprecated('改用 fileMd5(trackMd5);後端已不再比對 fingerprint')
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
