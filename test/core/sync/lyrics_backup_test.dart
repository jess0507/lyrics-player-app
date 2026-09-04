import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/core/sync/lyrics_backup.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';

void main() {
  test('encode → JSON → decode round-trip', () {
    final entity = LyricsEntity()
      ..trackId = 't1'
      ..title = 'Song'
      ..format = LyricsFormat.lrc
      ..source = LyricsSource.online
      ..content = '[00:01.00]hi\n[00:02.00]there'
      ..addedAt = DateTime.fromMillisecondsSinceEpoch(12345);

    final json = jsonDecode(jsonEncode(LyricsBackup.encodeLyrics([entity])));
    final decoded = LyricsBackup.decodeLyrics(json).single;

    expect(decoded.trackId, 't1');
    expect(decoded.title, 'Song');
    expect(decoded.format, LyricsFormat.lrc);
    expect(decoded.source, LyricsSource.online);
    expect(decoded.content, entity.content);
    expect(decoded.addedAt.millisecondsSinceEpoch, 12345);
  });

  test('缺 trackId 或空內文跳過;未知 format / source fallback', () {
    final decoded = LyricsBackup.decodeLyrics({
      'lyrics': [
        {'trackId': 'ok', 'content': 'x', 'format': 'weird', 'source': '??'},
        {'trackId': 'empty', 'content': ''},
        {'content': 'no id'},
        'garbage',
      ],
    });
    expect(decoded, hasLength(1));
    expect(decoded.single.trackId, 'ok');
    expect(decoded.single.format, LyricsFormat.txt);
    expect(decoded.single.source, LyricsSource.manual);
    expect(decoded.single.title, '');
    expect(decoded.single.addedAt.millisecondsSinceEpoch, 0);
  });

  test('缺 lyrics 欄位 → 空清單', () {
    expect(LyricsBackup.decodeLyrics({}), isEmpty);
  });
}
