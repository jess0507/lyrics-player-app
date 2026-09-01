import 'package:seek_player/features/music_list/models/track.dart';

/// 平台音樂庫來源:Android 掃 MediaStore(MediaStoreMusicSource)、
/// iOS 掃 app Documents 目錄(DocumentsMusicSource;方案 A,
/// 見 plans/23-ios-support.md)。實體由 musicLibrarySourceProvider 依平台提供。
abstract class MusicLibrarySource {
  /// 掃描並回傳全部曲目(標題排序)。
  Future<List<Track>> scan();

  /// 全庫音檔路徑(TrackAudioResolver 重算指紋比對時列舉用)。
  Future<List<String>> audioFilePaths();

  /// 解析「非內容指紋」的 fallback track id 對應的檔案路徑;無對應回 null。
  /// Android 的 fallback id 是 MediaStore 數字 id;iOS 是檔案路徑本身。
  Future<String?> pathForFallbackId(String trackId);
}
