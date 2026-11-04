import 'package:isar_community/isar.dart';

part 'track_cover_entity.g.dart';

/// 一首曲目的「使用者自訂封面」。Isar 只存圖檔路徑,實際圖檔落在 app 文件夾
/// `covers/` 下(Isar 不塞大 binary,圖檔放檔案系統可直接 `Image.file` 顯示)。
/// 純本機資料,綁定 [trackId],不同步 Firestore(換機遺失可接受)。
/// 已由 TrackEntity.coverImagePath / coverColorValue 取代,只保留給 TrackEntityMigration 讀取舊資料。
/// schema 仍須留在 openIsar() 的清單內(見 isar_service.dart)。
@Deprecated('改用 TrackEntity;僅供 TrackEntityMigration 讀取舊資料')
@collection
class TrackCoverEntity {
  Id id = Isar.autoIncrement;

  /// 舊版 trackId(檔案內容指紋 sha1)。唯一索引 replace:
  /// 同一曲重複設定直接覆蓋舊封面。
  @Index(unique: true, replace: true)
  late String trackId;

  /// 複製到 app 文件夾後的封面圖檔絕對路徑。
  late String imagePath;

  /// 預先算好的封面主色(ARGB int,[Color.toARGB32]);供播放頁的封面色漸層
  /// 即時取用,避免切歌時才解析圖片造成卡頓。舊資料 / 尚未解析時為 null,
  /// 由 [trackCoverColorProvider] 首次取用時補算並寫回。
  int? colorValue;

  late DateTime addedAt;
}
