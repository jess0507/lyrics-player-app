import 'package:isar_community/isar.dart';

part 'lyrics_entity.g.dart';

/// 一首曲目的歌詞「原始內文」。存原文不存解析結果——編輯(backlog 7)與
/// parser 演進都不被內部模型綁死,顯示時即時 parse(很快)。登入時由
/// SyncService 備份至 `user/{uid}/lyrics/{trackId}` 子集合(sync v5;
/// 推翻 v1「純本機不同步」決策,換機不再遺失歌詞)。
@collection
class LyricsEntity {
  Id id = Isar.autoIncrement;

  /// trackId(檔案內容指紋,見 TrackFingerprintService)。唯一索引 replace:
  /// 同一曲重複匯入直接覆蓋舊歌詞。
  @Index(unique: true, replace: true)
  late String trackId;

  /// 匯入當下的曲名,留作跨機 / 重掃後對齊的線索(v1 不做 title fallback 配對)。
  late String title;

  /// 內文格式,顯示時據此選 parser。
  @enumerated
  late LyricsFormat format;

  /// 歌詞來源(v1 僅 manual;online / generated 留給後續計畫複用本 entity)。
  @enumerated
  late LyricsSource source;

  /// 歌詞原文(解析的唯一依據;編輯計畫直接改這裡)。
  late String content;

  late DateTime addedAt;
}

/// 外部歌詞檔格式。順序影響 Isar ordinal 儲存值,新增請往後加,勿插入或重排。
enum LyricsFormat { lrc, srt, vtt, txt }

/// 歌詞來源。順序同上,勿重排。
enum LyricsSource { manual, online, generated }
