import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// 以 ffmpeg 抽出的內嵌封面快取檔位置(暫存目錄下,以 pathKey 為 key)。
/// pathKey 是 pathKey(含 '/'),以 sha1 產生安全檔名。
/// [embeddedArtworkProvider] 讀寫。
File embeddedArtworkCacheFile(Directory tmp, String pathKey) {
  final cacheKey = sha1.convert(utf8.encode(pathKey)).toString();
  return File('${tmp.path}/embedded_artwork_$cacheKey.jpg');
}
