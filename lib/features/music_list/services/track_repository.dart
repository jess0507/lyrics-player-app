import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/features/music_list/models/scanned_track.dart';
import 'package:seek_player/features/music_list/models/track_entity.dart';

/// [TrackEntity] 的 Isar CRUD。寫入一律以 pathKey upsert:讀出既有那筆、
/// 在上面改欄位再 `putByPathKey`,保留 id、[TrackEntity.addedAt] 與封面欄位。
class TrackRepository {
  TrackRepository(this._isar);

  final Isar _isar;

  IsarCollection<TrackEntity> get _col => _isar.trackEntitys;

  TrackEntity? findByPathKey(String pathKey) => _col.getByPathKeySync(pathKey);

  /// 同一次掃描內重複的 pathKey 只取第一筆。只寫入新增或欄位有變動的
  /// 曲目,沒變的不動([TrackEntity.updatedAt] 維持原值);全部在同一個
  /// transaction 內完成。
  ///
  /// 寫入一律用 writeTxnSync:統計 / 播放清單也是 sync 交易,同一個 isolate
  /// 混用 async 交易時,async 交易進行中開 sync 交易會丟 IsarError(例如
  /// 掃描曲庫途中換歌記錄播放)。
  Future<void> upsertAll(List<ScannedTrack> scanned) async {
    final unique = <String, ScannedTrack>{
      for (final s in scanned.reversed) s.pathKey: s,
    };
    if (unique.isEmpty) return;
    final keys = unique.keys.toList();
    _isar.writeTxnSync(() {
      final existing = _col.getAllByPathKeySync(keys);
      final now = DateTime.now();
      final changed = <TrackEntity>[];
      for (var i = 0; i < keys.length; i++) {
        final entity = _merge(existing[i], unique[keys[i]]!, now);
        if (entity != null) changed.add(entity);
      }
      if (changed.isNotEmpty) _col.putAllByPathKeySync(changed);
    });
  }

  /// 單筆 upsert(外部開啟 / 選檔比對),回傳寫入後的 entity。
  Future<TrackEntity> upsert(ScannedTrack scanned) async {
    late TrackEntity result;
    _isar.writeTxnSync(() {
      final existing = _col.getByPathKeySync(scanned.pathKey);
      final merged = _merge(existing, scanned, DateTime.now());
      if (merged != null) _col.putByPathKeySync(merged);
      result = merged ?? existing!;
    });
    return result;
  }

  /// [pathKeys] 中「找得到 track」者:有對應的 [TrackEntity],且檔案目前
  /// 存在。只有 entity、檔案已被刪除的視為找不到(下載同步據此決定要不要存)。
  Set<String> availablePathKeys(Iterable<String> pathKeys) {
    final keys = pathKeys.toSet().toList();
    final entities = _col.getAllByPathKeySync(keys);
    return {
      for (final e in entities)
        if (e != null && File(e.path).existsSync()) e.pathKey,
    };
  }

  /// 寫入音檔 / 歌詞 MD5 快取(只更新有帶的欄位);沒有 entity 時不寫入。
  ///
  /// 不更新 [TrackEntity.updatedAt]:MD5 只是本機快取,不算曲目資料變動,
  /// 不該觸發雲端同步。
  void setMd5(String pathKey, {String? audioMd5, String? lyricsMd5}) {
    if (audioMd5 == null && lyricsMd5 == null) return;
    _isar.writeTxnSync(() {
      final entity = _col.getByPathKeySync(pathKey);
      if (entity == null) return;
      if (audioMd5 != null) entity.audioMd5 = audioMd5;
      if (lyricsMd5 != null) entity.lyricsMd5 = lyricsMd5;
      _col.putByPathKeySync(entity);
    });
  }

  /// 新建或更新後的 entity;既有且所有欄位都沒變回 null(不需寫入)。
  static TrackEntity? _merge(
    TrackEntity? existing,
    ScannedTrack s,
    DateTime now,
  ) {
    if (existing != null &&
        existing.path == s.path &&
        existing.sizeBytes == s.sizeBytes &&
        existing.modifiedMs == s.modifiedMs &&
        existing.title == s.title &&
        existing.artist == s.artist &&
        existing.album == s.album &&
        existing.albumId == s.albumId &&
        existing.durationMs == s.durationMs) {
      return null;
    }
    final entity = existing ?? (TrackEntity()..addedAt = now);
    // 檔案本身變了(換路徑 / 大小 / mtime),先前算的內容 MD5 不再可信。
    if (existing != null &&
        (existing.path != s.path ||
            existing.sizeBytes != s.sizeBytes ||
            existing.modifiedMs != s.modifiedMs)) {
      entity.audioMd5 = null;
    }
    return entity
      ..path = s.path
      ..pathKey = s.pathKey
      ..sizeBytes = s.sizeBytes
      ..modifiedMs = s.modifiedMs
      ..title = s.title
      ..artist = s.artist
      ..album = s.album
      ..albumId = s.albumId
      ..durationMs = s.durationMs
      ..updatedAt = now;
  }
}

final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) => TrackRepository(ref.watch(isarProvider)),
);
