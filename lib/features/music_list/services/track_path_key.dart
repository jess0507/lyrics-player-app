import 'dart:io';

import 'package:path/path.dart' as p;

/// 把音訊檔路徑正規化成 **pathKey**:同一個實體檔案不論以哪種字串出現
/// (路徑別名、多餘的 `/`、大小寫),都算出同一個 key。pathKey 即曲目身份,
/// 是 [TrackEntity] 的唯一鍵,也是歌詞 / 統計 / 播放清單 / 雲端同步的關聯鍵。
///
/// 所有路徑進入點(曲庫掃描、外部開啟、選檔比對、遷移)都必須先經過
/// [of],不得直接拿原始路徑比對或寫入。

abstract final class TrackPathKey {
  /// Android 主要外部儲存的標準前綴;MediaStore `_data` 一律是這個形式。
  static const _primaryStorage = '/storage/emulated/0/';

  /// 指向主要外部儲存的常見別名(皆為 symlink)。
  static const _primaryAliases = [
    '/sdcard/',
    '/mnt/sdcard/',
    '/storage/self/primary/',
  ];

  /// 回傳 [rawPath] 的 pathKey。
  static String of(String rawPath) {
    var path = p.normalize(rawPath);
    for (final alias in _primaryAliases) {
      if (path.startsWith(alias)) {
        path = '$_primaryStorage${path.substring(alias.length)}';
        break;
      }
    }
    // `/storage/...` 是 MediaStore 的標準形式,不必再解析;其他來源
    // (例如外部開啟還原出的路徑)才嘗試解析 symlink 取真實路徑。
    if (!path.startsWith('/storage/')) path = _resolveSymlinks(path);
    // 共享儲存(FUSE)與 SD 卡(FAT / exFAT)皆不分大小寫。
    return path.toLowerCase();
  }

  static String _resolveSymlinks(String path) {
    try {
      return p.normalize(File(path).resolveSymbolicLinksSync());
    } on FileSystemException {
      // 檔案不存在 / 無權限:沿用前綴對照後的結果。
      return path;
    }
  }
}
