import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/playlists/models/local_music_view_state.dart';
import 'package:seek_player/features/tools/models/track_sort.dart';

/// 本機音樂頁的資料夾與排序紀錄;沒有紀錄時為全部 / 預設排序。
class LocalMusicViewController extends Notifier<LocalMusicViewState> {
  static const _kFolder = 'localMusic.folder';
  static const _kSortField = 'localMusic.sortField';
  static const _kSortDescending = 'localMusic.sortDescending';

  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  LocalMusicViewState build() => LocalMusicViewState(
    folder: _prefs.getString(_kFolder),
    sort: TrackSort.fromStored(
      _prefs.getString(_kSortField),
      _prefs.getBool(_kSortDescending),
    ),
  );

  void setFolder(String? path) {
    if (path == state.folder) return;
    state = LocalMusicViewState(folder: path, sort: state.sort);
    _writeFolder(path);
    _markModified();
  }

  void setSort(TrackSort sort) {
    final current = state.sort;
    if (sort.field == current.field && sort.descending == current.descending) {
      return;
    }
    state = LocalMusicViewState(folder: state.folder, sort: sort);
    _writeSort(sort);
    _markModified();
  }

  /// 以雲端狀態覆寫本機。還原不算本機變更,不更新 modifiedAt,避免還原後
  /// 馬上又觸發上傳。
  void restoreFromRemote(LocalMusicViewState restored) {
    state = restored;
    _writeFolder(restored.folder);
    _writeSort(restored.sort);
  }

  void _writeFolder(String? path) =>
      path == null ? _prefs.remove(_kFolder) : _prefs.setString(_kFolder, path);

  void _writeSort(TrackSort sort) {
    _prefs.setString(_kSortField, sort.field.name);
    _prefs.setBool(_kSortDescending, sort.descending);
  }

  void _markModified() =>
      ref.read(backupStateStoreProvider).markLocalMusicModified();
}

final localMusicViewControllerProvider =
    NotifierProvider<LocalMusicViewController, LocalMusicViewState>(
      LocalMusicViewController.new,
    );
