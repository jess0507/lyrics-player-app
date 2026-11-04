import 'package:seek_player/features/music_list/models/track.dart';

/// 音樂庫來源(Android 掃 MediaStore,見 MediaStoreMusicSource);
/// 實體由 musicLibrarySourceProvider 提供,測試可替換。
abstract class MusicLibrarySource {
  /// 掃描並回傳全部曲目(標題排序)。掃到的檔案同時 upsert 成
  /// TrackEntity,[Track.id] 為其 pathKey(見 TrackPathKey)。
  Future<List<Track>> scan();
}
