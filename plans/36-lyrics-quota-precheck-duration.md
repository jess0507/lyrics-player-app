# 36 - 歌詞雲端任務執行前檢查用量與音訊長度

## 背景

2026-10 有帳號單一任務記了 878 分鐘用量(上限 60 分鐘)。原本的限制只在
callable 檢查「已用量 ≥ 上限」,沒檢查這次音訊長度;Cloud Run 量出長度後直接
記帳,所以一個長音檔就能遠超上限。另外前端關卡讀錯欄位
(`freeUserMonthlyLimitMinutes`,雲端實際是 `freeUserMonthlyMinutes`),
且沒比對 `usage.month`,等於沒作用。

## 目標

在執行工作前就確認:

1. 本月額度尚未用完。
2. 「本月已用量 + 這段音訊長度」不超過上限。

## 設計

### 前端(seek_player)

- `AudioDurationProbe`(`lib/features/lyrics/usage_limit/audio_duration_probe.dart`):
  ffprobe 量實際檔案,失敗退回 `TrackEntity.durationMs`。
- `LyricsUsageLimitService.check({audioSeconds})` 回
  `LyricsUsageOk` / `LyricsUsageLimitReached` / `LyricsUsageInsufficient`。
  讀 `freeUserMonthlyMinutes`(相容舊名),`usage.month` 不是當月 UTC 視為 0。
- `ensureWithinUsageLimitForLyrics(pathKey:)` 在登入後、壓縮 / 上傳前檢查,
  不足時顯示 `lyrics_usage_insufficient_for_audio`(音訊分鐘數 / 剩餘分鐘數)。
- `generate_lyrics` / `align_lyrics` 呼叫多帶 `durationSeconds`。
- 前端只是提早提示;讀取失敗一律放行。

### 後端(seek_player_backend)

- callable:`_ensure_quota` 檢查已用量;有 `durationSeconds` 時檢查
  已用量 + 長度,超過回 `resource-exhausted` + `details.code = "quota_insufficient"`。
  派工 payload 帶 `quotaSeconds`(豁免帳號不帶)。
- Cloud Run(whisperx `/align`、`/transcribe`,aeneas `/align`):量出實際長度後
  以 `_reserve_monthly_usage` 在同一個 transaction 檢查並記帳,超過則不記帳、
  寫 `status = failed`、`error = quota_exceeded`。有 `quotaSeconds` 卻量不出長度
  時拒絕(`invalid_request`)。
- 沒帶 `quotaSeconds`(舊 Function 派的工)維持不限制,部署順序不影響。

## 已知限制

- 豁免帳號仍會累計用量,前端關卡不知道豁免名單,用量超過後會被前端擋下。
- 背景任務因 `quota_exceeded` 失敗時,app 顯示一般的失敗訊息(只在前端預檢
  被繞過時才會發生)。
- Cloud Run 被平台中斷(逾時 / OOM)時不會退回已記的用量,待另案處理。

## 部署順序

1. 後端 Cloud Run 服務(whisperx / aeneas)。
2. Firebase Functions。
3. App 新版。
