import 'dart:convert';

import 'package:seek_player/features/lyrics/models/lyrics.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';

/// 歌詞解析(純函式,可單元測試)。四種檔案格式各有小規則,自寫以統一輸出
/// 同一個 [Lyrics] 模型;壞檔以容錯為原則:略過無法解析的行,絕不整檔失敗。

/// 依副檔名判定格式;無法辨識者一律當純文字。
LyricsFormat detectLyricsFormat(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'lrc':
      return LyricsFormat.lrc;
    case 'srt':
      return LyricsFormat.srt;
    case 'vtt':
      return LyricsFormat.vtt;
    default:
      return LyricsFormat.txt;
  }
}

/// 依內文判定格式(貼上的文字沒有副檔名可依循):`WEBVTT` 開頭為 VTT、
/// 有 `-->` 時間行為 SRT、有行首 `[mm:ss]` 時間戳為 LRC,其餘當純文字。
LyricsFormat detectLyricsFormatFromContent(String content) {
  final body = content.trimLeft();
  if (body.startsWith('WEBVTT')) return LyricsFormat.vtt;
  if (_cueTime.hasMatch(body)) return LyricsFormat.srt;
  for (final line in const LineSplitter().convert(body)) {
    final m = _lrcTime.firstMatch(line);
    if (m != null && line.substring(0, m.start).trim().isEmpty) {
      return LyricsFormat.lrc;
    }
  }
  return LyricsFormat.txt;
}

/// 解析內文為內部模型。
Lyrics parseLyrics(String content, LyricsFormat format) {
  switch (format) {
    case LyricsFormat.lrc:
      return _parseLrc(content);
    case LyricsFormat.srt:
    case LyricsFormat.vtt:
      return _parseCues(content);
    case LyricsFormat.txt:
      return _parseText(content);
  }
}

// ── LRC ─────────────────────────────────────────────────────────────────────

/// `[mm:ss]` / `[mm:ss.xx]` / `[mm:ss.xxx]` 行時間戳。分鐘允許 3 位(長曲)。
final _lrcTime = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// `[offset:+/-ms]` ID tag(大小寫不拘)。
final _lrcOffset = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

/// Enhanced LRC 的逐字 `<mm:ss.xx>` 標記;v1 降級為整行,直接剝除。
final _lrcWord = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');

Lyrics _parseLrc(String content) {
  final offset = _readOffset(content);
  final lines = <LyricsLine>[];
  for (final raw in const LineSplitter().convert(content)) {
    final matches = _lrcTime.allMatches(raw).toList();
    if (matches.isEmpty) continue; // 檔頭 metadata / 空行:略過
    // 文字為最後一個時間戳之後的部分;剝除 enhanced 逐字標記。
    final text = raw
        .substring(matches.last.end)
        .replaceAll(_lrcWord, '')
        .trim();
    for (final m in matches) {
      // 一行多時間戳(副歌共用句)展開為多行,各帶自己的時間。
      lines.add(LyricsLine(time: _lrcTimeToDuration(m, offset), text: text));
    }
  }
  lines.sort((a, b) => a.time!.compareTo(b.time!));
  return Lyrics(lines: lines, synced: lines.isNotEmpty);
}

int _readOffset(String content) {
  final m = _lrcOffset.firstMatch(content);
  return m == null ? 0 : int.parse(m.group(1)!);
}

/// 正 offset 表示歌詞應提早顯示,故 effective = 標記時間 − offset(夾 ≥ 0)。
Duration _lrcTimeToDuration(RegExpMatch m, int offsetMs) {
  final minutes = int.parse(m.group(1)!);
  final seconds = int.parse(m.group(2)!);
  final ms = minutes * 60000 + seconds * 1000 + _fractionToMs(m.group(3));
  final adjusted = ms - offsetMs;
  return Duration(milliseconds: adjusted < 0 ? 0 : adjusted);
}

// ── SRT / WebVTT(時間區段,只取起始時間)──────────────────────────────────

/// `HH:MM:SS,mmm` 或 `MM:SS.mmm` 起迄時間(SRT 用逗號、VTT 用點,皆容許)。
final _cueTime = RegExp(
  r'(\d{1,2}:)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})\s*-->\s*',
);

Lyrics _parseCues(String content) {
  final lines = <LyricsLine>[];
  // 以空行分塊;每塊找含 `-->` 的時間行,其後各行為字幕文字。
  for (final block
      in content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
    final blockLines = block.split('\n');
    Duration? start;
    final text = <String>[];
    for (final line in blockLines) {
      final m = _cueTime.firstMatch(line);
      if (m != null && start == null) {
        start = _cueStartToDuration(m);
      } else if (start != null) {
        if (line.trim().isNotEmpty) text.add(line.trim());
      }
      // 時間行之前的序號 / `WEBVTT` 檔頭 / cue identifier 皆略過。
    }
    if (start != null && text.isNotEmpty) {
      lines.add(LyricsLine(time: start, text: text.join('\n')));
    }
  }
  lines.sort((a, b) => a.time!.compareTo(b.time!));
  return Lyrics(lines: lines, synced: lines.isNotEmpty);
}

Duration _cueStartToDuration(RegExpMatch m) {
  final hours = m.group(1) == null
      ? 0
      : int.parse(m.group(1)!.substring(0, m.group(1)!.length - 1));
  final minutes = int.parse(m.group(2)!);
  final seconds = int.parse(m.group(3)!);
  return Duration(
    milliseconds:
        hours * 3600000 +
        minutes * 60000 +
        seconds * 1000 +
        _fractionToMs(m.group(4)),
  );
}

// ── 純文字 ───────────────────────────────────────────────────────────────────

Lyrics _parseText(String content) {
  final lines = [
    for (final raw in const LineSplitter().convert(content))
      LyricsLine(time: null, text: raw.trimRight()),
  ];
  // 去除尾端連續空行,但保留中間空行作為段落間距。
  while (lines.isNotEmpty && lines.last.text.isEmpty) {
    lines.removeLast();
  }
  return Lyrics(lines: lines, synced: false);
}

// ── 共用 ─────────────────────────────────────────────────────────────────────

/// 小數秒轉毫秒:2 位為百分秒(×10)、3 位為毫秒、1 位為十分秒(×100)。
int _fractionToMs(String? fraction) {
  if (fraction == null || fraction.isEmpty) return 0;
  switch (fraction.length) {
    case 1:
      return int.parse(fraction) * 100;
    case 2:
      return int.parse(fraction) * 10;
    default:
      return int.parse(fraction);
  }
}
