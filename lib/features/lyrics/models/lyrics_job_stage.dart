/// 某曲進行中歌詞任務(自動產生 / 對時)的目前階段,供 `LyricsJobStatusView`
/// 顯示與通知列一致的文案。前三個階段來自本機 pipeline(壓縮 / 上傳 /
/// 呼叫後端),`requestSent` 表示 callable 已成功送出、正等 Firestore 回終態。
enum LyricsJobStage {
  generateCompressing,
  generateUploading,
  generateTranscribing,
  generateRequestSent,
  alignCompressing,
  alignUploading,
  alignAligning,
  alignRequestSent,
}
