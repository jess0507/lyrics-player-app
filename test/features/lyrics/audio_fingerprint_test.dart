// audioFingerprint 已 deprecated(改用 fileMd5),測試保留到移除為止。
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/features/lyrics/services/audio_fingerprint.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_fingerprint');
  });

  tearDown(() => tempDir.delete(recursive: true));

  const chunk = 64 * 1024;

  Uint8List bytesOf(int length) =>
      Uint8List.fromList(List.generate(length, (i) => i % 251));

  test('小檔(不超過兩個 chunk):sha1("size:" + 全部內容)', () async {
    final bytes = bytesOf(1000);
    final file = File('${tempDir.path}/small.mp3')..writeAsBytesSync(bytes);

    final expected = sha1.convert([
      ...utf8.encode('1000:'),
      ...bytes,
    ]).toString();
    expect(await audioFingerprint(file.path), expected);
  });

  test('大檔:sha1("size:" + 頭 64KB + 尾 64KB)', () async {
    final size = chunk * 3 + 123;
    final bytes = bytesOf(size);
    final file = File('${tempDir.path}/large.mp3')..writeAsBytesSync(bytes);

    final expected = sha1.convert([
      ...utf8.encode('$size:'),
      ...bytes.sublist(0, chunk),
      ...bytes.sublist(size - chunk),
    ]).toString();
    expect(await audioFingerprint(file.path), expected);
  });

  test('檔案不存在回 null', () async {
    expect(await audioFingerprint('${tempDir.path}/missing.mp3'), isNull);
  });
}
