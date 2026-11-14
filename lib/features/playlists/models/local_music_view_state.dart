import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';

/// 本機音樂頁的檢視狀態:資料夾篩選與排序。存在「本機音樂」系統清單
/// (播放清單 id 0,見 [PlaylistEntity.isLocalMusic])上,隨播放清單同步。
class LocalMusicViewState {
  const LocalMusicViewState({this.folder, this.sort = const TrackSort()});

  /// 由「本機音樂」清單取出;清單不存在([entity] 為 null)或沒有紀錄時為
  /// 全部 / 預設排序。本頁不提供清單順序,排序不接受 custom。
  factory LocalMusicViewState.fromEntity(PlaylistEntity? entity) =>
      entity == null
      ? const LocalMusicViewState()
      : LocalMusicViewState(
          folder: entity.folder,
          sort: TrackSort.fromStored(entity.sortField, entity.sortDescending),
        );

  /// 上次選的資料夾路徑;null 代表全部。路徑在目前曲庫不存在時頁面顯示
  /// 全部,但保留紀錄。
  final String? folder;

  /// 上次套用的排序。
  final TrackSort sort;
}
