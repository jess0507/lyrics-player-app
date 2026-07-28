import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';

/// 雲端同步的本機狀態：設定 / 播放清單 / 統計 / 歌詞各自最後一次本機
/// 變更的時間，供推 / 拉判斷用；另存一份「上次同步時間」純供帳戶
/// 頁面顯示。
///
/// 推 / 拉方向一律由 SyncService 直接比對 Firestore 當下
/// `user/{uid}/setting/0` 裡的 settingUpdatedAt / playlistUpdatedAt /
/// statsUpdatedAt / lyricsUpdatedAt 與這裡對應的 *ModifiedAt 決定（見
/// SyncService._shouldPull / _shouldPush），本機不另存一份「上次同步
/// 時間」鏡射參與判斷，避免兩邊出現落差。四個領域各自獨立比對、
/// 獨立推送，互不牽動（例如統計每次播放的變更不會連帶重推設定或歌詞）。
class SyncStateStore {
  SyncStateStore(this._prefs);

  static const _kLastSyncAt = 'sync.lastSyncAt';
  static const _kSettingModifiedAt = 'sync.settingModifiedAt';
  static const _kPlaylistModifiedAt = 'sync.playlistModifiedAt';
  static const _kStatsModifiedAt = 'sync.statsModifiedAt';
  static const _kLyricsModifiedAt = 'sync.lyricsModifiedAt';

  final PreferencesService _prefs;

  /// 上次成功同步（上傳或還原）的時間；null 表示從未同步。純供帳戶
  /// 頁面顯示，不參與推 / 拉判斷。
  DateTime? get lastSyncAt => _read(_kLastSyncAt);

  /// 上傳成功（或還原完成）時呼叫，更新 lastSyncAt 供帳戶頁面顯示。
  void markSynced() => _write(_kLastSyncAt, DateTime.now());

  /// 設定最後一次本機變更的時間；null 表示從未變更。
  DateTime? get settingModifiedAt => _read(_kSettingModifiedAt);

  /// 設定每次寫入時呼叫。
  void markSettingModified() => _write(_kSettingModifiedAt, DateTime.now());

  /// 播放清單最後一次本機變更的時間；null 表示從未變更。
  DateTime? get playlistModifiedAt => _read(_kPlaylistModifiedAt);

  /// 播放清單每次寫入時呼叫。
  void markPlaylistModified() => _write(_kPlaylistModifiedAt, DateTime.now());

  /// 統計最後一次本機變更的時間；null 表示從未變更。
  DateTime? get statsModifiedAt => _read(_kStatsModifiedAt);

  /// 統計每次寫入時呼叫。
  void markStatsModified() => _write(_kStatsModifiedAt, DateTime.now());

  /// 歌詞最後一次本機變更的時間；null 表示從未變更。
  DateTime? get lyricsModifiedAt => _read(_kLyricsModifiedAt);

  /// 歌詞每次寫入 / 刪除時呼叫。
  void markLyricsModified() => _write(_kLyricsModifiedAt, DateTime.now());

  DateTime? _read(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void _write(String key, DateTime value) =>
      _prefs.setInt(key, value.millisecondsSinceEpoch);
}

final syncStateStoreProvider = Provider<SyncStateStore>(
  (ref) => SyncStateStore(ref.watch(preferencesServiceProvider)),
);
