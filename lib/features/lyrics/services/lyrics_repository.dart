import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';

/// 歌詞的 Isar CRUD。儲存原文,解析交給讀取端(parser)。
/// 每次使用者寫入都 markLyricsModified,標記待推;實際上傳由
/// SyncService 在回前景 / 登入 / 統計重設時觸發,寫入當下不觸發推送。
class LyricsRepository {
  LyricsRepository(this._isar, this._syncState);

  final Isar _isar;
  final SyncStateStore _syncState;

  IsarCollection<LyricsEntity> get _col => _isar.lyricsEntitys;

  /// 依 trackId 取歌詞(唯一索引);查無回 null。
  LyricsEntity? findByTrackId(String trackId) => _col.getByTrackIdSync(trackId);

  /// 同步讀取全部歌詞(SyncService 上傳快照用)。
  List<LyricsEntity> getAllSync() => _col.where().findAllSync();

  /// upsert(唯一索引 replace:同曲覆蓋)。
  Future<void> save(LyricsEntity entity) async {
    await _isar.writeTxn(() => _col.put(entity));
    _syncState.markLyricsModified();
  }

  /// 移除某曲歌詞。
  Future<void> deleteByTrackId(String trackId) async {
    final deleted = await _isar.writeTxn(() => _col.deleteByTrackId(trackId));
    if (deleted) _syncState.markLyricsModified();
  }

  /// 還原雲端備份(整份覆寫本機)。
  /// 還原不算本機變更:不 markLyricsModified,避免還原後馬上又觸發上傳。
  Future<void> restoreFromRemote(List<LyricsEntity> entities) =>
      _isar.writeTxn(() async {
        await _col.clear();
        await _col.putAll(entities);
      });
}

final lyricsRepositoryProvider = Provider<LyricsRepository>(
  (ref) => LyricsRepository(
    ref.watch(isarProvider),
    ref.watch(syncStateStoreProvider),
  ),
);
