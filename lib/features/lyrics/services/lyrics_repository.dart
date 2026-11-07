import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';

/// 歌詞的 Isar CRUD。儲存原文,解析交給讀取端(parser)。
/// 每次使用者寫入都 markLyricsModified,標記待推;實際上傳由
/// GoogleDriveBackupService 在回前景 / 連結 Drive / 統計重設時觸發,寫入當下不觸發推送。
class LyricsRepository {
  LyricsRepository(this._isar, this._backupState);

  final Isar _isar;
  final BackupStateStore _backupState;

  IsarCollection<LyricsEntity> get _col => _isar.lyricsEntitys;

  /// 依 trackId 取歌詞;查無回 null。
  ///
  /// trackId 只有一般索引(見 LyricsEntity.trackId),一首一筆由本類別的
  /// 寫入([_put] / [_putAll])保證。
  LyricsEntity? findByTrackId(String trackId) =>
      _col.where().trackIdEqualTo(trackId).findFirstSync();

  /// 同 trackId 已有一筆時沿用它的 id(覆蓋),確保一首一筆。須在
  /// writeTxnSync 內呼叫。
  ///
  /// 本類別寫入一律用 writeTxnSync:統計 / 播放清單也是 sync 交易,同一個
  /// isolate 混用 async 交易時,async 交易進行中開 sync 交易會丟 IsarError。
  void _put(LyricsEntity entity) {
    final existing = findByTrackId(entity.trackId);
    if (existing != null) entity.id = existing.id;
    _col.putSync(entity);
  }

  /// 批次版 [_put];清單內同 trackId 以後面那筆為準。須在 writeTxnSync 內呼叫。
  void _putAll(List<LyricsEntity> entities) {
    final byTrackId = {for (final e in entities) e.trackId: e};
    byTrackId.values.forEach(_put);
  }

  /// 同步讀取全部**有內容**的歌詞(雲端同步 / 備份上傳快照用)。送出 AI
  /// 產生任務時建立的空內容 entity(只記 jobId)不算歌詞,不列入。
  List<LyricsEntity> getAllSync() =>
      _col.filter().contentIsNotEmpty().findAllSync();

  /// 送出後端歌詞任務時記下 [jobId]:已有歌詞(對時)只更新 jobId;還沒有
  /// 歌詞(AI 產生)就先建一筆空內容的 entity。不算使用者的歌詞變更,
  /// 不 markLyricsModified(空內容本來就不會被上傳)。
  Future<void> beginJob(
    String trackId, {
    required String jobId,
    required String title,
  }) async => _isar.writeTxnSync(() {
    final entity =
        findByTrackId(trackId) ??
        (LyricsEntity()
          ..trackId = trackId
          ..title = title
          ..format = LyricsFormat.lrc
          ..source = LyricsSource.generated
          ..content = ''
          ..addedAt = DateTime.now());
    entity.jobId = jobId;
    _put(entity);
  });

  /// 任務結束(失敗 / 取消 / 未送出)時收尾:內容仍是空的就刪掉這筆,
  /// 有內容(對時失敗)就只清掉 jobId。
  Future<void> clearJob(String trackId) async => _isar.writeTxnSync(() {
    final entity = findByTrackId(trackId);
    if (entity == null) return;
    if (entity.content.isEmpty) {
      _col.deleteSync(entity.id);
    } else if (entity.jobId != null) {
      entity.jobId = null;
      _col.putSync(entity);
    }
  });

  /// upsert(同 trackId 覆蓋)。
  Future<void> save(LyricsEntity entity) async {
    _isar.writeTxnSync(() => _put(entity));
    _backupState.markLyricsModified();
  }

  /// 移除某曲歌詞。
  Future<void> deleteByTrackId(String trackId) async {
    final deleted = _isar.writeTxnSync(
      () => _col.where().trackIdEqualTo(trackId).deleteAllSync(),
    );
    if (deleted > 0) _backupState.markLyricsModified();
  }

  /// 還原雲端備份(整份覆寫本機)。
  /// 還原不算本機變更:不 markLyricsModified,避免還原後馬上又觸發上傳。
  Future<void> restoreFromRemote(List<LyricsEntity> entities) async =>
      _isar.writeTxnSync(() {
        _col.clearSync();
        _putAll(entities);
      });
}

final lyricsRepositoryProvider = Provider<LyricsRepository>(
  (ref) => LyricsRepository(
    ref.watch(isarProvider),
    ref.watch(backupStateStoreProvider),
  ),
);
