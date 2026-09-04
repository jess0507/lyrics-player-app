/// 連結後首次同步的結果,更多頁的備份列據此挑 toast 文案。
enum SyncOutcome {
  /// 完成(含「沒有東西需要推 / 拉」)。
  done,

  /// 尚未連結 Google Drive,或 session 不可用。
  notLinked,

  /// 已有另一個同步任務在跑(回前景 / 統計重設),本次略過。
  busy,

  /// 授權已失效(401 / scope 被撤銷),需重新連結。
  needsRelink,

  /// 使用者的 Drive 空間已滿(上傳限定)。
  driveFull,

  /// 離線、逾時或其他錯誤。
  failed,
}
