import 'dart:convert';

/// 一首本機音訊曲目。
class Track {
  const Track({
    required this.id,
    required this.uri,
    required this.filePath,
    required this.title,
    this.artist,
    this.album,
    this.albumId,
    this.durationMs,
  });

  /// 穩定識別碼:檔案內容指紋(sha1,見 TrackFingerprintService),
  /// 跨裝置 / 重掃 / 換路徑對同一檔案不變;讀檔失敗時退回 MediaStore id。
  final String id;

  /// 可供 just_audio 載入的 URI（多為 MediaStore content URI）。
  final String uri;

  /// 裝置上實際檔案路徑（MediaStore `_data` 欄位）。content URI 無法還原
  /// 成檔案路徑，分享等需要真實檔案的場景要用這個而非 [uri]。
  final String filePath;
  final String title;
  final String? artist;
  final String? album;

  /// MediaStore 專輯 id;供 `OnAudioQuery.queryArtwork(ArtworkType.ALBUM)`
  /// 取內嵌封面用,封面圖本身不存進 Track。
  final int? albumId;

  final int? durationMs;

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  Track copyWith({int? durationMs}) => Track(
        id: id,
        uri: uri,
        filePath: filePath,
        title: title,
        artist: artist,
        album: album,
        albumId: albumId,
        durationMs: durationMs ?? this.durationMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uri': uri,
        'filePath': filePath,
        'title': title,
        'artist': artist,
        'album': album,
        'albumId': albumId,
        'durationMs': durationMs,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        uri: json['uri'] as String,
        filePath: json['filePath'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        albumId: json['albumId'] as int?,
        durationMs: json['durationMs'] as int?,
      );

  static String encodeList(List<Track> tracks) =>
      jsonEncode(tracks.map((t) => t.toJson()).toList());

  static List<Track> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList(growable: true);
  }
}
