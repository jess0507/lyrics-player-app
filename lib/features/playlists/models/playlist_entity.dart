import 'package:isar_community/isar.dart';

part 'playlist_entity.g.dart';

/// 一個使用者播放清單。曲目以 pathKey(見 TrackPathKey)的有序清單保存;
/// 顯示時再回 music library 解析成 [Track]。
/// 隨 Google Drive 備份連結備份至使用者的 Drive `playlists.json`(見 GoogleDriveBackupService)。
@collection
class PlaylistEntity {
  Id id = Isar.autoIncrement;

  /// 清單名稱。「我的最愛」此欄僅作 fallback,UI 以 [isFavorites] 顯示在地化名稱。
  late String name;

  /// 有序的 pathKey 清單(即播放順序);重複加入同曲不重覆附加。
  List<String> pathKeys = [];

  /// 凍結:升級前的舊識別碼清單(sha1 內容指紋 / MediaStore fallback id),
  /// 僅保留、不再寫入,不作為比對 / 同步依據(見 plans/33)。
  List<String> trackIds = [];

  late DateTime createdAt;

  /// 預設「我的最愛」清單:每裝置唯一、不可刪除 / 改名,永遠排在最前。
  @Index()
  bool isFavorites = false;

  /// 預設「最近播放」清單:每裝置唯一、不可編輯,由播放行為自動維護
  /// (見 [PlaylistRepository.recordRecentlyPlayed]),僅能整份清除。
  /// 曲目與播放時間記在 [recentlyPlayed],[pathKeys] 此清單不使用。
  @Index()
  bool isRecentlyPlayed = false;

  /// 「最近播放」清單專用:依播放時間新到舊排序,同曲重播會移到最前面。
  List<RecentlyPlayedEntry> recentlyPlayed = [];
}

/// 「最近播放」單筆紀錄:曲目與播放當下時間。
@embedded
class RecentlyPlayedEntry {
  late String pathKey;

  /// 升級前的舊識別碼(sha1 內容指紋 / MediaStore fallback id),僅保留,
  /// 不作為比對 / 同步依據;升級後新建的資料為 null(見 plans/33)。
  String? trackId;

  late DateTime playedAt;
}
