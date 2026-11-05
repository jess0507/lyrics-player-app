import 'package:flutter_test/flutter_test.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/services/lyrics_parser.dart';

void main() {
  group('detectLyricsFormat', () {
    test('依副檔名判定,大小寫不拘', () {
      expect(detectLyricsFormat('song.lrc'), LyricsFormat.lrc);
      expect(detectLyricsFormat('SONG.LRC'), LyricsFormat.lrc);
      expect(detectLyricsFormat('a.srt'), LyricsFormat.srt);
      expect(detectLyricsFormat('a.vtt'), LyricsFormat.vtt);
    });

    test('未知或無副檔名一律當純文字', () {
      expect(detectLyricsFormat('notes.txt'), LyricsFormat.txt);
      expect(detectLyricsFormat('README'), LyricsFormat.txt);
      expect(detectLyricsFormat('song.foo'), LyricsFormat.txt);
    });
  });

  group('detectLyricsFormatFromContent', () {
    test('行首 [mm:ss] 時間戳判為 LRC(容許前置 metadata / 空白)', () {
      expect(
        detectLyricsFormatFromContent('[ar:Someone]\n[00:12.34]hello'),
        LyricsFormat.lrc,
      );
      expect(
        detectLyricsFormatFromContent('\n  [01:02]line'),
        LyricsFormat.lrc,
      );
    });

    test('WEBVTT 開頭判為 VTT;有 --> 時間行判為 SRT', () {
      expect(
        detectLyricsFormatFromContent(
          'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhi',
        ),
        LyricsFormat.vtt,
      );
      expect(
        detectLyricsFormatFromContent('1\n00:00:01,000 --> 00:00:02,000\nhi'),
        LyricsFormat.srt,
      );
    });

    test('沒有時間標記、或時間戳不在行首,一律當純文字', () {
      expect(detectLyricsFormatFromContent('hello\nworld'), LyricsFormat.txt);
      expect(
        detectLyricsFormatFromContent('see [00:12] later'),
        LyricsFormat.txt,
      );
    });
  });

  group('LRC', () {
    test('標準:時間戳轉時間並依時間排序', () {
      const lrc = '[00:12.50]first\n[00:05.00]earlier\n[01:00.00]later';
      final lyrics = parseLyrics(lrc, LyricsFormat.lrc);

      expect(lyrics.synced, isTrue);
      expect(lyrics.lines.map((l) => l.text), ['earlier', 'first', 'later']);
      expect(lyrics.lines[0].time, const Duration(seconds: 5));
      expect(lyrics.lines[1].time, const Duration(seconds: 12, milliseconds: 500));
      expect(lyrics.lines[2].time, const Duration(minutes: 1));
    });

    test('ID tag 與空行略過,不致整檔失敗', () {
      const lrc = '[ti:Title]\n[ar:Artist]\n\n[00:01.00]real line';
      final lyrics = parseLyrics(lrc, LyricsFormat.lrc);

      expect(lyrics.lines, hasLength(1));
      expect(lyrics.lines.single.text, 'real line');
    });

    test('一行多時間戳展開為多行,共用文字', () {
      const lrc = '[00:10.00][00:20.00][00:30.00]chorus';
      final lyrics = parseLyrics(lrc, LyricsFormat.lrc);

      expect(lyrics.lines, hasLength(3));
      expect(lyrics.lines.every((l) => l.text == 'chorus'), isTrue);
      expect(lyrics.lines.map((l) => l.time), const [
        Duration(seconds: 10),
        Duration(seconds: 20),
        Duration(seconds: 30),
      ]);
    });

    test('offset 正值使歌詞提早(時間減去 offset,夾在 0)', () {
      const lrc = '[offset:500]\n[00:10.00]a\n[00:00.20]b';
      final lyrics = parseLyrics(lrc, LyricsFormat.lrc);

      // b: 200ms − 500ms → 夾為 0
      expect(lyrics.lines[0].text, 'b');
      expect(lyrics.lines[0].time, Duration.zero);
      // a: 10000ms − 500ms
      expect(lyrics.lines[1].text, 'a');
      expect(lyrics.lines[1].time, const Duration(milliseconds: 9500));
    });

    test('enhanced 逐字標記降級為整行(剝除 <> 標記)', () {
      const lrc = '[00:01.00]<00:01.00>Hello <00:01.50>world';
      final lyrics = parseLyrics(lrc, LyricsFormat.lrc);

      expect(lyrics.lines.single.text, 'Hello world');
      expect(lyrics.lines.single.time, const Duration(seconds: 1));
    });

    test('毫秒精度時間戳', () {
      const lrc = '[00:01.234]a';
      final lyrics = parseLyrics(lrc, LyricsFormat.lrc);
      expect(lyrics.lines.single.time, const Duration(milliseconds: 1234));
    });
  });

  group('SRT', () {
    test('取每段起始時間,多行字幕合併', () {
      const srt = '1\n'
          '00:00:01,000 --> 00:00:04,000\n'
          'line one\n'
          'line two\n'
          '\n'
          '2\n'
          '00:00:05,500 --> 00:00:08,000\n'
          'next';
      final lyrics = parseLyrics(srt, LyricsFormat.srt);

      expect(lyrics.synced, isTrue);
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].time, const Duration(seconds: 1));
      expect(lyrics.lines[0].text, 'line one\nline two');
      expect(lyrics.lines[1].time, const Duration(seconds: 5, milliseconds: 500));
    });
  });

  group('WebVTT', () {
    test('檔頭略過,毫秒用點,可省略小時', () {
      const vtt = 'WEBVTT\n'
          '\n'
          '00:01.000 --> 00:04.000\n'
          'hello\n'
          '\n'
          '00:00:05.000 --> 00:00:06.000\n'
          'world';
      final lyrics = parseLyrics(vtt, LyricsFormat.vtt);

      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines[0].time, const Duration(seconds: 1));
      expect(lyrics.lines[0].text, 'hello');
      expect(lyrics.lines[1].time, const Duration(seconds: 5));
    });
  });

  group('TXT', () {
    test('每行一筆,無時間戳,unsynced', () {
      const txt = 'line a\nline b\n';
      final lyrics = parseLyrics(txt, LyricsFormat.txt);

      expect(lyrics.synced, isFalse);
      expect(lyrics.lines.map((l) => l.text), ['line a', 'line b']);
      expect(lyrics.lines.every((l) => l.time == null), isTrue);
    });

    test('保留中間空行,去除尾端空行', () {
      const txt = 'verse 1\n\nverse 2\n\n\n';
      final lyrics = parseLyrics(txt, LyricsFormat.txt);

      expect(lyrics.lines.map((l) => l.text), ['verse 1', '', 'verse 2']);
    });
  });

  group('壞檔容錯', () {
    test('空字串:LRC / SRT 視為無內容', () {
      expect(parseLyrics('', LyricsFormat.lrc).isEmpty, isTrue);
      expect(parseLyrics('', LyricsFormat.srt).isEmpty, isTrue);
    });

    test('無時間戳的 LRC 內容回空(交由匯入端判定失敗)', () {
      final lyrics = parseLyrics('just\nplain\ntext', LyricsFormat.lrc);
      expect(lyrics.isEmpty, isTrue);
    });
  });
}
