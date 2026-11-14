import 'package:isar_community/isar.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';

part 'playlist_entity.g.dart';

/// 一個使用者播放清單。曲目以 trackId(音檔全檔 SHA-256)的有序清單保存;
/// 顯示時再回 music library 解析成 [Track]。
/// 隨 Google Drive 備份連結備份至使用者的 Drive `playlists.json`(見 GoogleDriveBackupService)。
@collection
class PlaylistEntity {
  Id id = Isar.autoIncrement;

  /// 清單名稱。「我的最愛」此欄僅作 fallback,UI 以 [isFavorites] 顯示在地化名稱。
  late String name;

  /// 有序的 trackId 清單(即播放順序);重複加入同曲不重覆附加。
  /// 升級前的舊資料為 sha1 內容指紋,由 TrackEntityMigration 改寫(見 plans/38)。
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

  /// 詳細頁上次套用的排序欄位(`TrackSortField.name`);null 為沒有紀錄,
  /// 依清單順序。「最近播放」不使用。
  String? sortField;

  /// 詳細頁上次套用的排序方向;null 時沿用預設方向。
  bool? sortDescending;

  /// 詳細頁要套用的排序:有紀錄用紀錄,否則依清單順序。
  @ignore
  TrackSort get sort => TrackSort.fromStored(
    sortField,
    sortDescending,
    fallback: const TrackSort(field: TrackSortField.custom),
    allowCustom: true,
  );
}

/// 「最近播放」單筆紀錄:曲目與播放當下時間。
@embedded
class RecentlyPlayedEntry {
  /// 曲目身份 trackId(音檔全檔 SHA-256)。
  late String trackId;

  late DateTime playedAt;
}
