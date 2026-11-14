import 'package:seek_player/features/tools/models/track_sort.dart';

/// 本機音樂頁的檢視狀態:資料夾篩選與排序。持久化於 SharedPreferences,
/// 並同步到 Firestore `user/{uid}/localMusic/0`(見 LocalMusicSync)。
class LocalMusicViewState {
  const LocalMusicViewState({this.folder, this.sort = const TrackSort()});

  /// 由雲端文件還原;缺欄位 / 未知值回預設。
  factory LocalMusicViewState.fromRemoteMap(Map<String, dynamic> map) =>
      LocalMusicViewState(
        folder: map['folder'] as String?,
        sort: TrackSort.fromStored(
          map['sortField'] as String?,
          map['sortDescending'] as bool?,
        ),
      );

  /// 上次選的資料夾路徑;null 代表全部。路徑在目前曲庫不存在時頁面顯示
  /// 全部,但保留紀錄。
  final String? folder;

  /// 上次套用的排序。
  final TrackSort sort;

  /// 雲端文件欄位(不含 `updatedAt`,由推送端加上)。
  Map<String, dynamic> toRemoteMap() => {
    'folder': folder,
    'sortField': sort.field.name,
    'sortDescending': sort.descending,
  };
}
