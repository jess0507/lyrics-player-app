import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/features/lyrics/services/content_md5.dart';

void main() {
  group('fileMd5', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('content_md5');
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('等於整個檔案內容的 md5', () async {
      final bytes = Uint8List.fromList(
        List.generate(300 * 1024 + 7, (i) => i % 251),
      );
      final file = File('${tempDir.path}/a.mp3')..writeAsBytesSync(bytes);

      expect(await fileMd5(file.path), md5.convert(bytes).toString());
    });

    test('內容不同 md5 就不同', () async {
      final a = File('${tempDir.path}/a.mp3')..writeAsBytesSync([1, 2, 3]);
      final b = File('${tempDir.path}/b.mp3')..writeAsBytesSync([1, 2, 4]);

      expect(await fileMd5(a.path), isNot(await fileMd5(b.path)));
    });

    test('檔案不存在回 null', () async {
      expect(await fileMd5('${tempDir.path}/missing.mp3'), isNull);
    });
  });

  group('lyricsLinesMd5', () {
    test('等於 md5(utf8(lines.join("\\n")))', () {
      const lines = ['第一行', 'second line'];
      expect(
        lyricsLinesMd5(lines),
        md5.convert(utf8.encode('第一行\nsecond line')).toString(),
      );
    });

    test('任一行不同 md5 就不同', () {
      expect(lyricsLinesMd5(['a', 'b']), isNot(lyricsLinesMd5(['a', 'c'])));
    });

    test('行的切分不同 md5 就不同', () {
      expect(lyricsLinesMd5(['ab']), isNot(lyricsLinesMd5(['a', 'b'])));
    });
  });
}
