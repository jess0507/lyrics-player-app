import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:seek_player/features/cover/models/track_cover_entity.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/music_list/models/track_entity.dart';
import 'package:seek_player/features/music_list/models/track_fingerprint_entity.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/models/period_stat_entity.dart';

/// 開啟 Isar 資料庫(曲目、歌詞、播放清單、聆聽統計;使用者設定仍用
/// SharedPreferences)。
Future<Isar> openIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [
      DailyTrackStatEntitySchema,
      PeriodStatEntitySchema,
      LyricsEntitySchema,
      PlaylistEntitySchema,
      TrackEntitySchema,
      // 以下兩個已由 TrackEntity 取代,schema 仍須保留:Isar 開啟時不在清單
      // 內的 collection 可能被刪除,而跳版升級的使用者仍要靠它們遷移
      // (見 TrackEntityMigration)。遷移完成後資料會被清空,空 collection
      // 幾乎沒有成本。
      TrackCoverEntitySchema,
      TrackFingerprintEntitySchema,
    ],
    directory: dir.path,
    name: 'seek_player',
  );
}

/// 於 main() 以 overrideWithValue 注入已開啟的實體。
final isarProvider = Provider<Isar>(
  (ref) => throw UnimplementedError('isarProvider 必須被覆寫'),
);
