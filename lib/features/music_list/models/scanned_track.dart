/// 掃描 / 外部開啟等來源讀到的一個音訊檔,交給 TrackRepository upsert
/// 成 [TrackEntity]。[trackId](音檔全檔 SHA-256)由呼叫端算好。
class ScannedTrack {
  const ScannedTrack({
    required this.path,
    required this.trackId,
    required this.sizeBytes,
    required this.modifiedMs,
    this.title,
    this.artist,
    this.album,
    this.albumId,
    this.durationMs,
  });

  final String path;
  final String trackId;
  final int sizeBytes;
  final int modifiedMs;
  final String? title;
  final String? artist;
  final String? album;
  final int? albumId;
  final int? durationMs;
}
