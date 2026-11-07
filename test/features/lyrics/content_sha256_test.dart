import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/features/lyrics/services/content_sha256.dart';

void main() {
  group('fileSha256', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('content_sha256');
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('等於整個檔案內容的 sha256', () async {
      final bytes = Uint8List.fromList(
        List.generate(300 * 1024 + 7, (i) => i % 251),
      );
      final file = File('${tempDir.path}/a.mp3')..writeAsBytesSync(bytes);

      expect(await dartFileSha256(file.path), sha256.convert(bytes).toString());
    });

    test('內容不同 sha256 就不同', () async {
      final a = File('${tempDir.path}/a.mp3')..writeAsBytesSync([1, 2, 3]);
      final b = File('${tempDir.path}/b.mp3')..writeAsBytesSync([1, 2, 4]);

      expect(await dartFileSha256(a.path), isNot(await dartFileSha256(b.path)));
    });

    test('檔案不存在回 null', () async {
      expect(await dartFileSha256('${tempDir.path}/missing.mp3'), isNull);
    });
  });

  group('lyricsLinesSha256', () {
    test('等於 sha256(utf8(lines.join("\\n")))', () {
      const lines = ['第一行', 'second line'];
      expect(
        lyricsLinesSha256(lines),
        sha256.convert(utf8.encode('第一行\nsecond line')).toString(),
      );
    });

    test('任一行不同 sha256 就不同', () {
      expect(
        lyricsLinesSha256(['a', 'b']),
        isNot(lyricsLinesSha256(['a', 'c'])),
      );
    });

    test('行的切分不同 sha256 就不同', () {
      expect(lyricsLinesSha256(['ab']), isNot(lyricsLinesSha256(['a', 'b'])));
    });
  });
}
