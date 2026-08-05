import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';

/// 我的最愛清單 DB 內存名 fallback;僅初始化時寫入,UI 一律以在地化字串顯示。
const _defaultFavoritesFallbackName = 'Favorites';

/// 最近播放清單 DB 內存名 fallback;僅初始化時寫入,UI 一律以在地化字串顯示。
const _defaultRecentlyPlayedFallbackName = 'Recently Played';

/// 最近播放上限筆數,超過時捨棄最舊的。
const _recentlyPlayedLimit = 200;

/// 播放清單的 Isar CRUD。曲目以有序 trackId 清單保存,解析交給讀取端。
/// 每次使用者寫入都 markPlaylistModified,標記待推;實際上傳由
/// SyncService 在回前景 / 登入 / 統計重設時觸發,寫入當下不觸發推送。
class PlaylistRepository {
  PlaylistRepository(this._isar, this._syncState);

  final Isar _isar;
  final SyncStateStore _syncState;

  IsarCollection<PlaylistEntity> get _col => _isar.playlistEntitys;

  /// 監聽所有播放清單(含初始值);排序交給衍生 provider。
  Stream<List<PlaylistEntity>> watchAll() =>
      _col.where().watch(fireImmediately: true);

  /// 同步讀取全部清單(SyncService 上傳快照用)。
  List<PlaylistEntity> getAllSync() => _col.where().findAllSync();

  /// 確保預設「我的最愛」清單存在;DB 內存名僅作 fallback(初始化時無
  /// [BuildContext] 可取在地化字串),UI 會以 [isFavorites] 覆寫顯示。
  /// 已存在則 no-op。
  /// 屬初始化而非使用者變更,不 markModified,避免全新安裝就觸發上傳。
  Future<void> ensureDefaultFavorites() async {
    final existing = _col.filter().isFavoritesEqualTo(true).findFirstSync();
    if (existing != null) return;
    await _isar.writeTxn(
      () => _col.put(
        PlaylistEntity()
          ..name = _defaultFavoritesFallbackName
          ..isFavorites = true
          ..createdAt = DateTime.now(),
      ),
    );
  }

  /// 確保預設「最近播放」清單存在;DB 內存名僅作 fallback,UI 會以
  /// [isRecentlyPlayed] 覆寫顯示。已存在則 no-op。
  /// 屬初始化而非使用者變更,不 markModified,避免全新安裝就觸發上傳。
  Future<void> ensureDefaultRecentlyPlayed() async {
    final existing = _col
        .filter()
        .isRecentlyPlayedEqualTo(true)
        .findFirstSync();
    if (existing != null) return;
    await _isar.writeTxn(
      () => _col.put(
        PlaylistEntity()
          ..name = _defaultRecentlyPlayedFallbackName
          ..isRecentlyPlayed = true
          ..createdAt = DateTime.now(),
      ),
    );
  }

  /// 還原雲端備份(整份覆寫本機,含我的最愛)。
  /// 還原不算本機變更:不 markModified,避免還原後馬上又觸發上傳。
  Future<void> restoreFromRemote(List<PlaylistEntity> playlists) =>
      _isar.writeTxn(() async {
        await _col.clear();
        await _col.putAll(playlists);
      });

  /// 新增清單,回傳新 id。
  ///
  /// id 取現有清單最大值 + 1,不吃 Isar 內建 autoIncrement 計數器：
  /// 該計數器不會因 [restoreFromRemote] 寫入的外來 id（雲端 `playlist`
  /// 子集合 docId）往前跳號，若沿用會導致新清單 id 撞號、覆寫掉剛還原
  /// 的清單。
  Future<int> create(String name) async {
    final id = await _isar.writeTxn(() {
      final maxId = _col.where().findAllSync().fold<int>(
        0,
        (max, p) => p.id > max ? p.id : max,
      );
      return _col.put(
        PlaylistEntity()
          ..id = maxId + 1
          ..name = name
          ..createdAt = DateTime.now(),
      );
    });
    _syncState.markPlaylistModified();
    return id;
  }

  /// 改名(我的最愛由 UI 擋下,不會走到這裡)。
  Future<void> rename(int id, String name) async {
    final changed = await _isar.writeTxn(() async {
      final pl = await _col.get(id);
      if (pl == null) return false;
      pl.name = name;
      await _col.put(pl);
      return true;
    });
    if (changed) _syncState.markPlaylistModified();
  }

  Future<void> delete(int id) async {
    final deleted = await _isar.writeTxn(() => _col.delete(id));
    if (deleted) _syncState.markPlaylistModified();
  }

  /// 加入一首(已存在則不重覆附加)。
  Future<void> addTrack(int id, String trackId) async {
    final changed = await _isar.writeTxn(() async {
      final pl = await _col.get(id);
      if (pl == null || pl.trackIds.contains(trackId)) return false;
      pl.trackIds = [...pl.trackIds, trackId];
      await _col.put(pl);
      return true;
    });
    if (changed) _syncState.markPlaylistModified();
  }

  Future<void> removeTrack(int id, String trackId) async {
    final changed = await _isar.writeTxn(() async {
      final pl = await _col.get(id);
      if (pl == null) return false;
      pl.trackIds = pl.trackIds.where((t) => t != trackId).toList();
      await _col.put(pl);
      return true;
    });
    if (changed) _syncState.markPlaylistModified();
  }

  /// 記一筆最近播放:該曲若已在清單中先移除,再插回最前面連同當下時間
  /// (最新播放永遠在最前),超過 [_recentlyPlayedLimit] 筆時捨棄最舊的。
  Future<void> recordRecentlyPlayed(String trackId) async {
    final changed = await _isar.writeTxn(() async {
      final pl = await _col.filter().isRecentlyPlayedEqualTo(true).findFirst();
      if (pl == null) return false;
      final rest = pl.recentlyPlayed.where((e) => e.trackId != trackId);
      pl.recentlyPlayed = [
        RecentlyPlayedEntry()
          ..trackId = trackId
          ..playedAt = DateTime.now(),
        ...rest,
      ].take(_recentlyPlayedLimit).toList();
      await _col.put(pl);
      return true;
    });
    if (changed) _syncState.markPlaylistModified();
  }

  /// 清空「最近播放」清單。
  Future<void> clearRecentlyPlayed() async {
    final changed = await _isar.writeTxn(() async {
      final pl = await _col.filter().isRecentlyPlayedEqualTo(true).findFirst();
      if (pl == null || pl.recentlyPlayed.isEmpty) return false;
      pl.recentlyPlayed = [];
      await _col.put(pl);
      return true;
    });
    if (changed) _syncState.markPlaylistModified();
  }

  /// 整批覆寫順序(拖曳排序用)。
  Future<void> setTrackIds(int id, List<String> trackIds) async {
    final changed = await _isar.writeTxn(() async {
      final pl = await _col.get(id);
      if (pl == null) return false;
      pl.trackIds = trackIds;
      await _col.put(pl);
      return true;
    });
    if (changed) _syncState.markPlaylistModified();
  }
}

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(
    ref.watch(isarProvider),
    ref.watch(syncStateStoreProvider),
  ),
);
