import 'package:flutter_test/flutter_test.dart';
import 'package:seek_player/features/lyrics/auto_align/lyrics_align_lines.dart';

void main() {
  group('splitLyricsForAlignment', () {
    test('全形句讀處斷行,標點留在前一段', () {
      expect(splitLyricsForAlignment(['我走了，你還在。明天見！']), [
        '我走了，',
        '你還在。',
        '明天見！',
      ]);
    });

    test('全形標點後的右引號跟著前一段', () {
      expect(splitLyricsForAlignment(['他說「再見。」然後離開']), ['他說「再見。」', '然後離開']);
    });

    test('半形標點只在後面接空白時斷', () {
      expect(splitLyricsForAlignment(['Hold on, I\'m coming. Wait for me']), [
        'Hold on,',
        'I\'m coming.',
        'Wait for me',
      ]);
    });

    test('詞內半形標點(小數、縮寫)不斷', () {
      expect(splitLyricsForAlignment(['Version 3.5 by Mr.Smith']), [
        'Version 3.5 by Mr.Smith',
      ]);
    });

    test('只有標點的片段併回前一段', () {
      expect(splitLyricsForAlignment(['好，，。再來']), ['好，，。', '再來']);
    });

    test('沒有標點的行原樣保留,去掉前後空白與空行', () {
      expect(splitLyricsForAlignment(['  第一行  ', '', '   ', '第二行']), [
        '第一行',
        '第二行',
      ]);
    });

    test('多行輸入依序展開', () {
      expect(splitLyricsForAlignment(['一，二', '三']), ['一，', '二', '三']);
    });
  });
}
