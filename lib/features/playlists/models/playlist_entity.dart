import 'package:isar_community/isar.dart';

part 'playlist_entity.g.dart';

/// 一個使用者播放清單。曲目以 trackId(檔案內容指紋)的有序清單保存;
/// 顯示時再回 music library 解析成 [Track]。
/// 隨帳號備份至 Firestore `user/{uid}`(見 SyncService)。
@collection
class PlaylistEntity {
  Id id = Isar.autoIncrement;

  /// 清單名稱。「我的最愛」此欄僅作 fallback,UI 以 [isFavorites] 顯示在地化名稱。
  late String name;

  /// 有序的 trackId 清單(即播放順序);重複加入同曲不重覆附加。
  List<String> trackIds = [];

  late DateTime createdAt;

  /// 預設「我的最愛」清單:每裝置唯一、不可刪除 / 改名,永遠排在最前。
  @Index()
  bool isFavorites = false;

  /// 預設「最近播放」清單:每裝置唯一、不可編輯,由播放行為自動維護
  /// (見 [PlaylistRepository.recordRecentlyPlayed]),僅能整份清除。
  /// 曲目與播放時間記在 [recentlyPlayed],[trackIds] 此清單不使用。
  @Index()
  bool isRecentlyPlayed = false;

  /// 「最近播放」清單專用:依播放時間新到舊排序,同曲重播會移到最前面。
  List<RecentlyPlayedEntry> recentlyPlayed = [];
}

/// 「最近播放」單筆紀錄:曲目與播放當下時間。
@embedded
class RecentlyPlayedEntry {
  late String trackId;
  late DateTime playedAt;
}
