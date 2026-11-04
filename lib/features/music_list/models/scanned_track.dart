/// 掃描 / 外部開啟等來源讀到的一個音訊檔,交給 TrackRepository upsert
/// 成 [TrackEntity]。[pathKey] 由呼叫端以 TrackPathKey.of 算好。
class ScannedTrack {
  const ScannedTrack({
    required this.path,
    required this.pathKey,
    required this.sizeBytes,
    required this.modifiedMs,
    this.title,
    this.artist,
    this.album,
    this.albumId,
    this.durationMs,
  });

  final String path;
  final String pathKey;
  final int sizeBytes;
  final int modifiedMs;
  final String? title;
  final String? artist;
  final String? album;
  final int? albumId;
  final int? durationMs;
}
