import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/features/music_list/models/scanned_track.dart';
import 'package:seek_player/features/music_list/models/track_entity.dart';

/// [TrackEntity] 的 Isar CRUD。寫入一律以 path upsert:讀出既有那筆、
/// 在上面改欄位再 `putByPath`,保留 id、[TrackEntity.addedAt] 與封面欄位。
///
/// 曲目身份是 trackId(音檔全檔 SHA-256);內容相同的多個檔案各一筆 entity、
/// 共用同一個 trackId。
class TrackRepository {
  TrackRepository(this._isar);

  final Isar _isar;

  IsarCollection<TrackEntity> get _col => _isar.trackEntitys;

  TrackEntity? findByPath(String path) => _col.getByPathSync(path);

  /// [trackId] 的所有 entity(內容相同的多個檔案)。
  List<TrackEntity> findAllByTrackId(String trackId) =>
      _col.where().trackIdEqualTo(trackId).findAllSync();

  /// [trackId] 的代表 entity:優先取檔案目前存在的那筆;都不存在取第一筆;
  /// 沒有 entity 回 null。
  TrackEntity? findByTrackId(String trackId) {
    final all = findAllByTrackId(trackId);
    if (all.isEmpty) return null;
    for (final e in all) {
      if (File(e.path).existsSync()) return e;
    }
    return all.first;
  }

  /// [paths] 已存在的 entity(依 path 對照)。
  Map<String, TrackEntity> findAllByPath(Iterable<String> paths) {
    final keys = paths.toSet().toList();
    final entities = _col.getAllByPathSync(keys);
    return {for (final e in entities.nonNulls) e.path: e};
  }

  /// 同一次掃描內重複的 path 只取第一筆。只寫入新增或欄位有變動的
  /// 曲目,沒變的不動([TrackEntity.updatedAt] 維持原值);全部在同一個
  /// transaction 內完成。
  ///
  /// 寫入一律用 writeTxnSync:統計 / 播放清單也是 sync 交易,同一個 isolate
  /// 混用 async 交易時,async 交易進行中開 sync 交易會丟 IsarError(例如
  /// 掃描曲庫途中換歌記錄播放)。
  Future<void> upsertAll(List<ScannedTrack> scanned) async {
    final unique = <String, ScannedTrack>{
      for (final s in scanned.reversed) s.path: s,
    };
    if (unique.isEmpty) return;
    final keys = unique.keys.toList();
    _isar.writeTxnSync(() {
      final existing = _col.getAllByPathSync(keys);
      final now = DateTime.now();
      final changed = <TrackEntity>[];
      for (var i = 0; i < keys.length; i++) {
        final entity = _merge(existing[i], unique[keys[i]]!, now);
        if (entity != null) changed.add(entity);
      }
      if (changed.isNotEmpty) _col.putAllByPathSync(changed);
    });
  }

  /// 單筆 upsert(外部開啟 / 選檔比對),回傳寫入後的 entity。
  Future<TrackEntity> upsert(ScannedTrack scanned) async {
    late TrackEntity result;
    _isar.writeTxnSync(() {
      final existing = _col.getByPathSync(scanned.path);
      final merged = _merge(existing, scanned, DateTime.now());
      if (merged != null) _col.putByPathSync(merged);
      result = merged ?? existing!;
    });
    return result;
  }

  /// [trackIds] 中「找得到 track」者:有對應的 [TrackEntity],且其中至少
  /// 一個檔案目前存在。只有 entity、檔案都已被刪除的視為找不到(下載同步
  /// 據此決定要不要存)。
  Set<String> availableTrackIds(Iterable<String> trackIds) {
    final ids = trackIds.toSet();
    if (ids.isEmpty) return const {};
    final entities = _col
        .filter()
        .anyOf(ids, (q, id) => q.trackIdEqualTo(id))
        .findAllSync();
    return {
      for (final e in entities)
        if (File(e.path).existsSync()) e.trackId,
    };
  }

  /// 記錄 [trackId] 最近一次送對時的歌詞 SHA-256;沒有 entity 時不寫入。
  ///
  /// 不更新 [TrackEntity.updatedAt]:hash 只是本機快取,不算曲目資料變動,
  /// 不該觸發雲端同步。
  void setLyricsSha256(String trackId, String lyricsSha256) {
    _isar.writeTxnSync(() {
      final entities = findAllByTrackId(trackId);
      if (entities.isEmpty) return;
      for (final e in entities) {
        e.lyricsSha256 = lyricsSha256;
      }
      _col.putAllByPathSync(entities);
    });
  }

  /// 新建或更新後的 entity;既有且所有欄位都沒變回 null(不需寫入)。
  static TrackEntity? _merge(
    TrackEntity? existing,
    ScannedTrack s,
    DateTime now,
  ) {
    if (existing != null &&
        existing.trackId == s.trackId &&
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
    return entity
      ..path = s.path
      ..trackId = s.trackId
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
