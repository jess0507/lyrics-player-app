/// 系統選檔器的防重入:`file_picker` 同一時間只允許一個選檔 / 存檔請求,
/// 前一個還沒結束(選檔器開著,或選完後 plugin 還在複製檔案)時再呼叫會拋
/// `PlatformException(already_active)`。
///
/// 所有 `FilePicker.pickFiles` / `FilePicker.saveFile` 都經 [run] 呼叫:進行中
/// 再進來的請求(例如連點)直接回 null,呼叫端視同使用者取消。
/// 這裡只擋重入、不吞例外——plugin 仍拋錯時照常往外傳並上報。
abstract final class FilePickerGuard {
  static bool _active = false;

  static Future<T?> run<T>(Future<T?> Function() open) async {
    if (_active) return null;
    _active = true;
    try {
      return await open();
    } finally {
      _active = false;
    }
  }
}
