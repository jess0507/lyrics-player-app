import 'dart:convert';

import 'package:crypto/crypto.dart';

/// pathKey→ 可當 Firestore 文件 id / map key 的字串。pathKey 含
/// `/`(不能當 doc id)與 `.`(map key 路徑分隔),以 sha1 轉成固定 40 碼
/// hex;原始 pathKey 另存在文件 / map 值的 `pathKey` 欄位,還原時讀它。
String trackDocKey(String pathKey) =>
    sha1.convert(utf8.encode(pathKey)).toString();
