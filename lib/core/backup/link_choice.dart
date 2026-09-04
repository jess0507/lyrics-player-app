/// 連結 Google Drive 後發現雲端已有備份時,使用者的選擇。
enum LinkChoice {
  /// 以雲端備份覆寫本機四領域資料。
  useCloud,

  /// 保留本機資料,整份推上去覆寫雲端備份。
  keepLocal,
}
