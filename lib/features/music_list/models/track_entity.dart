import 'package:isar_community/isar.dart';

part 'track_entity.g.dart';

/// 一個實體音訊檔一筆,以 [pathKey](見 TrackPathKey)為唯一鍵。
///
/// [pathKey] 即曲目身份:歌詞、統計、播放清單、雲端同步都以它關聯。
/// [id] 只是 Isar 主鍵,不對外使用、不存進任何關聯欄位。
///
/// 寫入一律用產生的 `putByPathKey`(同 key 已存在時更新該筆、保留原 id)。
/// `putByIndex` 是整筆覆寫,更新時必須先 `getByPathKey` 讀出舊的那筆、
/// 在上面改欄位再寫回,否則 [addedAt]、封面等沒帶到的欄位會被蓋掉。
/// 唯一索引刻意不加 `replace`:誤用一般 `put()` 時直接報錯,而不是換新 id。
@collection
class TrackEntity {
  Id id = Isar.autoIncrement;

  /// 實際讀檔用的路徑(MediaStore `_data` 絕對路徑)。
  late String path;

  /// 同一實體檔案的唯一鍵(曲目身份)。
  @Index(unique: true)
  late String pathKey;

  /// metadata 快取失效判斷:兩者皆未變就不重讀 metadata。
  late int sizeBytes;
  late int modifiedMs;

  String? title;
  String? artist;
  String? album;

  /// Android MediaStore 專輯 id(通知列專輯封面用)。
  int? albumId;

  int? durationMs;

  /// 自訂封面圖檔路徑(app `covers/` 目錄內);null 表示沒有自訂封面。
  String? coverImagePath;

  /// 自訂封面主色(ARGB),播放頁漸層用;null 表示尚未計算。
  int? coverColorValue;

  /// 音檔全檔內容 SHA-256(64 碼 hex),送 AI 產生 / 對時任務時當 `trackId`
  /// 給後端判斷同一首歌。null 表示尚未計算;[path] / [sizeBytes] /
  /// [modifiedMs] 變動時由 TrackRepository 清掉,下次送任務再重算。
  String? audioSha256;

  /// 最近一次送對時的歌詞 SHA-256(見 `lyricsLinesSha256`),隨任務當
  /// `lyricsSha256` 給後端:歌詞改過就是不同任務,不沿用舊的對時結果。
  String? lyricsSha256;

  /// 第一次建立時設定,之後不再改變。
  late DateTime addedAt;

  /// 任一欄位變動時更新。
  late DateTime updatedAt;
}
