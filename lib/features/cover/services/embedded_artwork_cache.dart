import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// 以 ffmpeg 抽出的內嵌封面快取檔位置(暫存目錄下,以 trackId 為 key)。
/// trackId 可能是 fallback 的檔案路徑(含 '/'),以 sha1 產生安全檔名。
/// [embeddedArtworkProvider] 寫入、[NotificationArtworkResolver] 讀取共用。
File embeddedArtworkCacheFile(Directory tmp, String trackId) {
  final cacheKey = sha1.convert(utf8.encode(trackId)).toString();
  return File('${tmp.path}/embedded_artwork_$cacheKey.jpg');
}
