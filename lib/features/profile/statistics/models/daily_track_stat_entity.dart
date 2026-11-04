import 'package:isar_community/isar.dart';

part 'daily_track_stat_entity.g.dart';

/// 每日 × 每首歌的聆聽記錄（一天一首歌一筆），統計的唯一儲存來源。
///
/// 不存任何總和——累計總量、排行、每日總量皆由讀取時聚合導出。
/// 日期取裝置本地時區。
@collection
class DailyTrackStatEntity {
  Id id = Isar.autoIncrement;

  /// 本地日期，格式 `yyyy-MM-dd`（字串排序即時間排序）。
  ///
  /// 與 [pathKey] 組成一天一曲一筆,由 StatisticsController 寫入時沿用既有
  /// 那筆的 id 保證。刻意不設 unique:舊資料升級時 [pathKey] 讀出來全是 `''`,
  /// 開 DB 重建 unique index 會衝突(見 plans/33)。
  @Index(composite: [CompositeIndex('pathKey')])
  late String day;

  /// 曲目身份(= TrackEntity.pathKey,見 TrackPathKey);[title] 一併保存,
  /// 顯示層以 title 聚合,對不到本機曲目的舊紀錄仍能正常統計(這類舊紀錄的
  /// pathKey 暫以舊 [trackId] 填入)。
  late String pathKey;

  /// 升級前的舊識別碼(sha1 內容指紋 / MediaStore fallback id),僅保留,
  /// 不作為比對 / 同步依據;升級後新建的資料為 null(見 plans/33)。
  String? trackId;

  late String title;

  /// 當日該曲播放次數。
  int playCount = 0;

  /// 當日該曲聆聽時長（毫秒）。
  int listenMs = 0;
}
