/// 一個備份領域(設定 / 播放清單 / 統計 / 歌詞)在 Google Drive 上對應
/// 一個 JSON 檔;各領域只負責「本機 ↔ JSON Map」的編解碼,序列化、上傳
/// 下載與推 / 拉判斷統一由 SyncGoogleDriveService 處理。
abstract class DomainBackup {
  /// appDataFolder 內的檔名(`settings.json` 等)。
  String get fileName;

  /// 領域名稱(log 用)。
  String get label;

  /// 本機最後一次變更時間(SyncStateStore),供推 / 拉判斷;null 表示從未變更。
  DateTime? get localModifiedAt;

  /// 讀本機資料,產出要上傳的 JSON Map。
  Map<String, dynamic> encode();

  /// 以雲端 JSON Map 整份覆寫本機。讀取一律容錯:缺欄位給預設值、
  /// 未知 enum fallback、格式不符的條目跳過。還原不算本機變更
  /// (不更新 *ModifiedAt),避免還原後馬上又觸發上傳。
  Future<void> restore(Map<String, dynamic> json);
}
