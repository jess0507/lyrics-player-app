import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/features/music_list/services/track_path_key.dart';

void main() {
  group('TrackPathKey.of', () {
    test('MediaStore 標準路徑:只轉小寫', () {
      expect(
        TrackPathKey.of('/storage/emulated/0/Music/周杰倫/晴天.MP3'),
        '/storage/emulated/0/music/周杰倫/晴天.mp3',
      );
    });

    test('主要外部儲存的別名對回 /storage/emulated/0', () {
      const expected = '/storage/emulated/0/music/a.mp3';
      expect(TrackPathKey.of('/sdcard/Music/a.mp3'), expected);
      expect(TrackPathKey.of('/mnt/sdcard/Music/a.mp3'), expected);
      expect(
        TrackPathKey.of('/storage/self/primary/Music/a.mp3'),
        expected,
      );
    });

    test('多餘的 / 與 . / .. 會被整理', () {
      expect(
        TrackPathKey.of('/storage/emulated/0/Music//x/../a.mp3'),
        '/storage/emulated/0/music/a.mp3',
      );
      expect(
        TrackPathKey.of('/storage/emulated/0/./Music/a.mp3'),
        '/storage/emulated/0/music/a.mp3',
      );
    });

    test('SD 卡路徑保留卷冊 id,只轉小寫', () {
      expect(
        TrackPathKey.of('/storage/1A2B-3C4D/Music/A.flac'),
        '/storage/1a2b-3c4d/music/a.flac',
      );
    });

    test('不存在的非 /storage 路徑:解析 symlink 失敗時沿用原路徑', () {
      expect(
        TrackPathKey.of('/data/user/0/pkg/files/Song.mp3'),
        '/data/user/0/pkg/files/song.mp3',
      );
    });
  });
}
