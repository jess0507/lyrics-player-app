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
}
