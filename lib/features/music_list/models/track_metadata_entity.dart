import 'package:isar_community/isar.dart';

part 'track_metadata_entity.g.dart';

/// 一個本機音訊檔的 tag 中繼資料快取(路徑 -> title/artist/album/duration)。
///
/// iOS 的 Documents 掃描(DocumentsMusicSource)沒有 MediaStore 可查 tag,
/// 需以 ffprobe 逐檔讀取;結果以 (size, mtime) 為條件快取,
/// 檔案沒變不重跑 ffprobe。
@collection
class TrackMetadataEntity {
  Id id = Isar.autoIncrement;

  /// 檔案絕對路徑。唯一索引 replace:同路徑重讀直接覆蓋。
  @Index(unique: true, replace: true)
  late String path;

  late int sizeBytes;

  /// 檔案最後修改時間(epoch ms);與 [sizeBytes] 一起判斷快取是否仍有效。
  late int modifiedMs;

  /// 以下皆來自音檔 tag,讀不到就是 null(由呼叫端 fallback,例如以檔名
  /// 當標題)。
  String? title;
  String? artist;
  String? album;
  int? durationMs;
}
