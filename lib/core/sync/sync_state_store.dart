import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_service.dart';

/// 雲端同步的本機狀態：本機資料最後變更時間，供推 / 拉判斷用；
/// 另存一份「上次同步時間」純供帳戶頁面顯示。
///
/// 推 / 拉方向一律由 SyncService 直接比對 Firestore 當下的 updatedAt
/// 與這裡的 lastModifiedAt / lyricsModifiedAt 決定（見
/// SyncService._shouldPull / _shouldPush），本機不另存一份「上次同步
/// 時間」鏡射參與判斷，避免兩邊出現落差。
/// 統計與設定的寫入端呼叫 [markModified]；歌詞走子集合、上傳成本高
/// （逐曲文件），另用獨立時戳 [markLyricsModified]，避免統計每次播放
/// 的變更都連帶重推全部歌詞。
class SyncStateStore {
  SyncStateStore(this._prefs);

  static const _kLastSyncAt = 'sync.lastSyncAt';
  static const _kLastModifiedAt = 'sync.lastModifiedAt';
  static const _kLyricsModifiedAt = 'sync.lyricsModifiedAt';

  final PreferencesService _prefs;

  /// 上次成功同步（上傳或還原）的時間；null 表示從未同步。純供帳戶
  /// 頁面顯示，不參與推 / 拉判斷。
  DateTime? get lastSyncAt => _read(_kLastSyncAt);

  /// 統計或設定最後一次本機變更的時間；null 表示從未變更。
  DateTime? get lastModifiedAt => _read(_kLastModifiedAt);

  /// 統計或設定每次寫入時呼叫。
  void markModified() => _write(_kLastModifiedAt, DateTime.now());

  /// 播放清單每次寫入時呼叫（變更時戳與統計 / 設定共用主文件那組）。
  void markPlaylistModified() => markModified();

  /// 上傳成功（或還原完成）時呼叫，更新 lastSyncAt 供帳戶頁面顯示。
  void markSynced() => _write(_kLastSyncAt, DateTime.now());

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
