import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/features/music_list/models/track_entity.dart';

/// 自訂封面的 Isar 讀寫,存在 [TrackEntity.coverImagePath] /
/// [TrackEntity.coverColorValue]。只存圖檔路徑,圖檔本體由 service 管理。
///
/// 封面掛在 TrackEntity 上:沒有 entity 的曲目(外部開啟、還原不出實體
/// 路徑的暫時曲目)無法設定封面。
class TrackCoverRepository {
  TrackCoverRepository(this._isar);

  final Isar _isar;

  IsarCollection<TrackEntity> get _col => _isar.trackEntitys;

  /// 依 trackId 取有自訂封面的 entity;沒有 entity 或沒有封面回 null。
  /// 封面以曲目身份為單位:同 trackId 的多個檔案共用同一張封面。
  TrackEntity? findByTrackId(String trackId) {
    for (final e in _col.where().trackIdEqualTo(trackId).findAllSync()) {
      if (e.coverImagePath != null) return e;
    }
    return null;
  }

  /// 取所有有封面但尚未快取主色的曲目,供載入音樂後背景補算。
  List<TrackEntity> findMissingColor() => _col
      .filter()
      .coverImagePathIsNotNull()
      .coverColorValueIsNull()
      .findAllSync();

  /// 設定封面;沒有 entity 時不寫入並回 false。
  Future<bool> setCover(
    String trackId, {
    required String imagePath,
    int? colorValue,
  }) => _update(trackId, (e) {
    e
      ..coverImagePath = imagePath
      ..coverColorValue = colorValue;
  });

  /// 寫回封面主色(既有封面不變)。
  Future<void> setColor(String trackId, int colorValue) =>
      _update(trackId, (e) => e.coverColorValue = colorValue);

  /// 移除某曲封面紀錄。
  Future<void> clearCover(String trackId) => _update(trackId, (e) {
    e
      ..coverImagePath = null
      ..coverColorValue = null;
  });

  /// 用 writeTxnSync:統計 / 播放清單也是 sync 交易,同一個 isolate 混用
  /// async 交易時,async 交易進行中開 sync 交易會丟 IsarError。
  ///
  /// 同 trackId 的所有 entity 一起更新。
  Future<bool> _update(
    String trackId,
    void Function(TrackEntity) apply,
  ) async => _isar.writeTxnSync(() {
    final entities = _col.where().trackIdEqualTo(trackId).findAllSync();
    if (entities.isEmpty) return false;
    final now = DateTime.now();
    for (final e in entities) {
      apply(e);
      e.updatedAt = now;
    }
    _col.putAllByPathSync(entities);
    return true;
  });
}

final trackCoverRepositoryProvider = Provider<TrackCoverRepository>(
  (ref) => TrackCoverRepository(ref.watch(isarProvider)),
);
