import 'package:isar_community/isar.dart';

part 'track_fingerprint_entity.g.dart';

/// 一個本機音訊檔的內容指紋快取(路徑 -> hash)。
///
/// 掃描音樂庫時,檔案大小與 mtime 未變就直接沿用 [hash],
/// 避免每次掃描都重讀檔案內容(TrackFingerprintService,已移除)。
/// 已由 TrackEntity.trackId 取代(指紋機制已移除),只保留給 TrackEntityMigration 讀取舊資料。
/// schema 仍須留在 openIsar() 的清單內(見 isar_service.dart)。
@Deprecated('改用 TrackEntity;僅供 TrackEntityMigration 讀取舊資料')
@collection
class TrackFingerprintEntity {
  Id id = Isar.autoIncrement;

  /// 檔案絕對路徑。唯一索引 replace:同路徑重算直接覆蓋。
  @Index(unique: true, replace: true)
  late String path;

  late int sizeBytes;

  /// 檔案最後修改時間(epoch ms);與 [sizeBytes] 一起判斷快取是否仍有效。
  late int modifiedMs;

  /// 內容指紋(即 track id):sha1(檔案大小 + 頭 64KB + 尾 64KB)的 hex。
  late String hash;
}
