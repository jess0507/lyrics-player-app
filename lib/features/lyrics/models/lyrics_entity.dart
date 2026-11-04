import 'package:isar_community/isar.dart';

part 'lyrics_entity.g.dart';

/// 一首曲目的歌詞「原始內文」。存原文不存解析結果——編輯(backlog 7)與
/// parser 演進都不被內部模型綁死,顯示時即時 parse(很快)。連結 Google Drive 後由
/// GoogleDriveBackupService 備份至使用者 Drive 的 `lyrics.json`(plan 26;
/// 推翻 v1「純本機不同步」決策,換機不再遺失歌詞)。
@collection
class LyricsEntity {
  Id id = Isar.autoIncrement;

  /// 曲目身份(= TrackEntity.pathKey,見 TrackPathKey)。一首一筆,由
  /// LyricsRepository 寫入時沿用既有那筆的 id 保證。
  ///
  /// 刻意不加 unique index:舊資料升級時這個欄位讀出來全是 `''`,開 DB 重建
  /// unique index 會衝突(見 plans/33)。
  @Index(type: IndexType.hash)
  late String pathKey;

  /// 升級前的舊識別碼(sha1 內容指紋 / MediaStore fallback id),僅保留,
  /// 不作為比對 / 同步依據;升級後新建的資料為 null(見 plans/33)。
  String? trackId;

  /// 匯入當下的曲名,留作跨機 / 重掃後對齊的線索(v1 不做 title fallback 配對)。
  late String title;

  /// 內文格式,顯示時據此選 parser。
  @enumerated
  late LyricsFormat format;

  /// 歌詞來源(v1 僅 manual;online / generated 留給後續計畫複用本 entity)。
  @enumerated
  late LyricsSource source;

  /// 歌詞原文(解析的唯一依據;編輯計畫直接改這裡)。
  ///
  /// 可能為空字串:送出「AI 產生」任務時先建一筆空內容的 entity 記 [jobId]。
  /// 「有沒有歌詞」一律以 content 是否為空判斷,不以 entity 是否存在判斷。
  late String content;

  /// 最近一次送出、尚未收尾的後端歌詞任務 id(`user/{uid}/lyrics/{jobId}`);
  /// 任務結束(成功 / 失敗 / 取消)後清為 null。
  String? jobId;

  late DateTime addedAt;
}

/// 外部歌詞檔格式。順序影響 Isar ordinal 儲存值,新增請往後加,勿插入或重排。
enum LyricsFormat { lrc, srt, vtt, txt }

/// 歌詞來源。順序同上,勿重排。
enum LyricsSource { manual, online, generated }
