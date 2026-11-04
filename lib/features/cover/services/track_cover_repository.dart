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

  /// 依 pathKey 取有自訂封面的 entity;沒有 entity 或沒有封面回 null。
  TrackEntity? findByPathKey(String pathKey) {
    final entity = _col.getByPathKeySync(pathKey);
    return entity?.coverImagePath == null ? null : entity;
  }

  /// 取所有有封面但尚未快取主色的曲目,供載入音樂後背景補算。
  List<TrackEntity> findMissingColor() => _col
      .filter()
      .coverImagePathIsNotNull()
      .coverColorValueIsNull()
      .findAllSync();

  /// 設定封面;沒有 entity 時不寫入並回 false。
  Future<bool> setCover(
    String pathKey, {
    required String imagePath,
    int? colorValue,
  }) => _update(pathKey, (e) {
    e
      ..coverImagePath = imagePath
      ..coverColorValue = colorValue;
  });

  /// 寫回封面主色(既有封面不變)。
  Future<void> setColor(String pathKey, int colorValue) =>
      _update(pathKey, (e) => e.coverColorValue = colorValue);

  /// 移除某曲封面紀錄。
  Future<void> clearCover(String pathKey) => _update(pathKey, (e) {
    e
      ..coverImagePath = null
      ..coverColorValue = null;
  });

  Future<bool> _update(String pathKey, void Function(TrackEntity) apply) =>
      _isar.writeTxn(() async {
        final entity = await _col.getByPathKey(pathKey);
        if (entity == null) return false;
        apply(entity);
        entity.updatedAt = DateTime.now();
        await _col.putByPathKey(entity);
        return true;
      });
}

final trackCoverRepositoryProvider = Provider<TrackCoverRepository>(
  (ref) => TrackCoverRepository(ref.watch(isarProvider)),
);
