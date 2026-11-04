import 'package:seek_player/features/music_list/models/track.dart';

/// 平台音樂庫來源:Android 掃 MediaStore(MediaStoreMusicSource)、
/// 實體由 musicLibrarySourceProvider 提供,測試可替換。
abstract class MusicLibrarySource {
  /// 掃描並回傳全部曲目(標題排序)。
  Future<List<Track>> scan();

  /// 全庫音檔路徑(TrackAudioResolver 重算指紋比對時列舉用)。
  Future<List<String>> audioFilePaths();

  /// 解析「非內容指紋」的 fallback track id 對應的檔案路徑;無對應回 null。
  /// fallback id 是 MediaStore 數字 id。
  Future<String?> pathForFallbackId(String trackId);
}
