# 35 - 各功能使用量 GA 事件

## 目標
每個使用者觸發的功能動作都記一筆 GA 事件,用來找出使用度高的功能、決定開發時間分配。
接續 plan 34(`firebase_analytics`、`screen_view`、`lyrics_action`)。

## 事件結構
- **一個功能一個事件**,以 `action` 參數區分動作:
  `player_action`、`mini_player_action`、`lyrics_action`、`library_action`、
  `playlist_action`、`tools_action`、`cover_action`、`account_action`、
  `backup_action`、`settings_action`、`statistics_action`、`profile_action`。
- 共用參數(全部 optional,除 `action`):
  - `action`:動作 enum(snake_case)。
  - `source`:入口 / 來源畫面(`AnalyticsSource`),同動作多入口時才帶。
  - `option`:使用者選的值(enum / 數字 / bool)。
  - `result`:結果(`AnalyticsResult` 或功能自己的錯誤 enum)。
- 全部定義在 `lib/core/analytics/analytics_events.dart`;各功能動作 enum 實作
  `AnalyticsAction`(指定所屬事件),`LyricsMenuAction` 也直接實作。
- 呼叫:`logAnalyticsAction(PlayerAction.share, source: ..., option: ..., result: ...)`。
- enum 名稱即 GA 名稱(自動 snake_case),命名後勿改;新增值往後加。

## 記錄原則
- 記在 **UI 入口**(按鈕 / 選單 / sheet 選項),不記在 service / controller:
  service 會被自動流程呼叫(開始播放時自動 `play()`、外部檔案自動開播放頁等),
  而且通知列 / 鎖定畫面控制直接走 just_audio,記在 service 也不完整。
- 高頻 handler(slider `onChanged`、圖表 touch、搜尋 `onChanged`)只在結束點記:
  `onChangeEnd`、tap up / pan end、離開搜尋時。
- 自動觸發(自動重掃、建立清單後自動開加歌頁)不記。
- 已由 router `screen_view` 涵蓋的純導頁不記;但播放頁、加歌頁、編輯頁是
  非 GoRouter 的 push,需另記入口。`/tools/:tool` 分不出工具種類,另記 `select_tool`。
- 隱私:不送 pathKey、歌名、資料夾 / 播放清單名稱、搜尋字、email、電話。

## 已知限制
- 「重設 app」後 process 立即結束,事件可能來不及上傳(GA SDK 無 flush API)。
- 隱藏中的 Drive 連結 UI 已加事件,重新顯示後才會有資料。

## GA 後台設定(分析使用量)
1. 管理 → 資料顯示 → **自訂定義** → 建立自訂維度(範圍:事件):
   `action`、`source`、`option`、`result`(參數名照填)。註冊後才開始累積,不回溯。
2. 報表 → 參與 → **事件**:看各 `*_action` 事件數 / 使用者數 → 哪個功能最常用。
3. 探索 → 任意形式:維度「事件名稱」+「action」(+「source」),指標「事件計數」
   「使用者總數」→ 功能內各動作排行。建議看「使用者數」而非事件數,避免少數重度
   使用者灌量。
4. 漏斗探索:例如歌詞 `ai_generate`(選單)→ `ai_generate_submit` → 成功,看流失點。
5. 需要逐筆 / 長期分析時開 BigQuery 匯出(plan 34)。
