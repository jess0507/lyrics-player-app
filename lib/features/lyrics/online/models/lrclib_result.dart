/// LRCLIB(https://lrclib.net/docs)API 回傳的單筆候選結果。與內部
/// [Lyrics](`../../models/lyrics.dart`)模型分開,避免顯示模型被外部 API
/// schema 綁死。
class LrclibResult {
  const LrclibResult({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.durationSeconds,
    required this.instrumental,
    this.plainLyrics,
    this.syncedLyrics,
  });

  factory LrclibResult.fromJson(Map<String, dynamic> json) => LrclibResult(
    id: json['id'] as int,
    trackName: json['trackName'] as String? ?? '',
    artistName: json['artistName'] as String? ?? '',
    albumName: json['albumName'] as String?,
    durationSeconds: (json['duration'] as num?)?.toDouble(),
    instrumental: json['instrumental'] as bool? ?? false,
    plainLyrics: json['plainLyrics'] as String?,
    syncedLyrics: json['syncedLyrics'] as String?,
  );

  final int id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final double? durationSeconds;

  /// 純演奏曲;LRCLIB 標記為無歌詞內容,不列入候選。
  final bool instrumental;

  final String? plainLyrics;
  final String? syncedLyrics;

  bool get hasSyncedLyrics => syncedLyrics != null && syncedLyrics!.isNotEmpty;

  bool get hasPlainLyrics => plainLyrics != null && plainLyrics!.isNotEmpty;

  bool get hasLyrics => !instrumental && (hasSyncedLyrics || hasPlainLyrics);
}
