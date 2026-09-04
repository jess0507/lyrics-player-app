/// 使用者主動觸發「同步到雲端 / 同步到本地」的結果,備份頁據此挑 toast 文案。
enum SyncOutcome {
  /// 完成(含「沒有東西需要推 / 拉」)。
  done,

  /// 尚未連結 Google Drive,或 session 不可用。
  notLinked,

  /// 授權已失效(401 / scope 被撤銷),需重新連結。
  needsRelink,

  /// 使用者的 Drive 空間已滿(同步到雲端限定)。
  driveFull,

  /// 雲端沒有任何備份檔(同步到本地限定)。
  nothingToRestore,

  /// 離線、逾時或其他錯誤。
  failed,
}
