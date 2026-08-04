# 歌詞功能:上網搜尋歌詞(backlog 1)

狀態:**待實作**(規劃階段;2026-08-04 訂出來源與架構)。
相關:`plans/11-lyrics-import.md`(本計畫複用其 `LyricsEntity` / `lyrics_repository` /
`track_lyrics_provider` 資料層,`LyricsSource.online` 已預留)、
`plans/10-lyrics-display.md`(顯示端不需改動,消費同一份 `LyricsEntity`)、
`plans/19-becklog.md`(v2 backlog 項目 1)。

## 背景 / 目標

- 曲目來自 MediaStore 掃描,無內嵌歌詞;目前取得歌詞的方式只有手動匯入
  (`lyrics-import.md`)與自動對時 / 自動產生(均需先有音訊或既有文字)。
- 使用者常見情境是「這首歌別人早就有現成歌詞檔,不想自己找檔案匯入」,
  需要一個「直接在 App 內查詢並套用」的入口。
- `LyricsEntity.source` 已預留 `LyricsSource.online`(見 `models/lyrics_entity.dart:27`),
  資料層本計畫只需「寫入」,不需改 schema。

## 線上歌詞來源選型

- **採用 [LRCLIB](https://lrclib.net/docs)**:免費、無需 API key、無速率限制、
  支援 CORS,直接回傳 LRC 格式(與既有 `lyrics_parser.dart` 相容),同時提供
  synced 與 plain 兩種內容。
- **不採用 Musixmatch**:免費層僅回傳歌詞片段預覽,完整歌詞需商業授權,
  不適合個人專案長期合規使用。
- **不採用網易雲第三方 API**:曲庫涵蓋華語較完整,但屬非官方逆向工程專案,
  需自架 Node.js 後端當 proxy(無法從 App 端直連穩定公開 API),官方隨時
  可能改版失效,維運成本與法律風險都偏高;列為後續備援來源,不進 v1。
- **排除 Genius**:官方 API 不提供歌詞內容本身(需另爬蟲,違反其 ToS),且
  資料庫只有純文字、無時間軸,不符合同步捲動需求。
- 已知限制:LRCLIB 對華語歌曲命中率明顯低於歐美/日系曲庫,查無結果是
  預期情境之一(見下方邊界)。

## 修改 / 新增程式碼檔案

新增(`lib/features/lyrics/`,依 CLAUDE.md 一檔一 provider):

- `online/models/lrclib_result.dart` — LRCLIB API 回傳的候選結果模型
  (id / trackName / artistName / albumName / duration / syncedLyrics /
  plainLyrics),與內部 `Lyrics` 模型分開,避免顯示模型被外部 API schema 綁死。
- `online/services/lrclib_client.dart` — 純函式包 HTTP 呼叫(`get`/`search`
  endpoint),回傳 `List<LrclibResult>`;逾時 / 非 200 拋自訂例外。
- `online/services/lyrics_online_search_service.dart` — 組合層:帶入
  title/artist/album/durationMs 查詢 → 候選結果 → 使用者選定後轉存
  `LyricsEntity`(`source = LyricsSource.online`)並呼叫既有
  `lyricsRepositoryProvider.save`。
- `online/providers/lrclib_client_provider.dart` — client 本體 provider。
- `online/providers/lyrics_online_search_provider.dart` — 依 query 觸發搜尋的
  `FutureProvider.family`(或 `AsyncNotifierProvider`,若需保留使用者手動
  重新查詢的動作)。

新增(UI,`lib/features/player/widgets/`):

- `lyrics_online_search_action.dart` — 比照 `lyrics_auto_sync_action.dart` /
  `lyrics_auto_generate_action.dart` 的既有模式:觸發搜尋、loading / 錯誤 /
  查無結果 UI 回饋。
- `lyrics_online_search_results_sheet.dart` — 多筆候選結果時的選擇 bottom sheet
  (單筆或高信心相符時可省略,直接套用)。

修改:

- `pubspec.yaml` — 加 `http`(專案目前無任何 HTTP client 依賴,僅此一個新依賴;
  不用 `dio`,LRCLIB 呼叫單純,不需要攔截器 / 進階功能)。
- `lib/features/player/widgets/lyrics_menu_action.dart` — `LyricsMenuAction`
  新增 `searchOnline`,排在 `autoGenerate` 與 `import` 之後(無歌詞時三種取得
  方式並列);`lyricsMenuActions()` 依 `!hasLyrics` 條件納入;
  `runLyricsMenuAction()` 分派到新 action 檔。**不需登入**(LRCLIB 為公開
  API,無需比照 `autoGenerate`/`autoSync` 走 `ensureSignedInForLyrics` /
  用量限制)。
- `lib/l10n/app_en.arb` / `app_zh_TW.arb` / `app_zh_CN.arb` — 新增
  `lyrics_search_online` / `lyrics_search_online_no_result` /
  `lyrics_search_online_failed` / `lyrics_search_online_select` 等 key,
  照慣例三語系全加、其餘 fallback,**待辦:補進 Google Sheet**。

## 結論(設計決策)

1. **查詢參數用 title + artist + album + durationMs**:皆已存在於現有
   `Track` model(`music_list/models/track.dart`),不需額外資料。
2. **寫入既有 `LyricsEntity`,不另建 entity**:`source = online` 已預留,
   查詢成功套用即等同「匯入」,行為與匯入完全一致(唯一索引 replace、
   顯示端 `track_lyrics_provider` 不需改動)。
3. **多筆候選結果需使用者確認**:LRCLIB 以文字比對配對,同名曲(尤其
   翻唱、live 版)可能有多筆,不做「自動選第一筆」以免套錯歌詞;僅當
   duration 完全相符且僅一筆時可考慮直接套用(實作時視配對品質調整)。
4. **不做離線佇列 / 背景任務**:與 `autoGenerate`/`autoSync` 不同,LRCLIB
   查詢是同步、輕量的單次 HTTP 請求,不需要 `usesBackgroundTask` 標記或
   前景服務排隊機制。
5. **失敗與查無結果分開處理**:網路錯誤 / 逾時顯示可重試的錯誤訊息;
   查無結果顯示中性提示並保留手動匯入入口,不視為錯誤。

## 步驟

1. **依賴**:加 `http`。
2. **API 層**:`lrclib_result.dart`(模型)、`lrclib_client.dart`(`get` 依
   title/artist/album 精確查詢、`search` 模糊查詢兩個 endpoint 都包);
   確認回傳的 `syncedLyrics` 內容與 `lyrics_parser.dart` 既有 LRC 解析相容。
3. **組合層**:`lyrics_online_search_service.dart`(查詢 → 候選 →
   轉 `LyricsEntity` → `lyricsRepositoryProvider.save`)+
   provider 檔(client / search)。
4. **選單整合**:`lyrics_menu_action.dart` 加 `searchOnline` action;
   新增 `lyrics_online_search_action.dart`(觸發 + loading/錯誤/查無結果)、
   `lyrics_online_search_results_sheet.dart`(多筆候選選擇,單筆高信心可
   省略此步)。
5. **l10n**:上述四個 key,照慣例 en + zh_TW + zh_CN。
6. 驗證:`flutter analyze`;實機走一輪(常見英文曲命中、華語曲常見查無
   結果、多筆候選選擇、離線 / 逾時錯誤提示、套用後歌詞頁正確顯示且
   `LyricsEntity.source == online`)。

## 邊界 / 風險

- **華語曲庫命中率低**:LRCLIB 以歐美/日系曲庫為主,查無結果為常見情境,
  UI 需清楚導向「改用手動匯入」而非讓使用者以為功能故障。
- **無官方 SLA**:LRCLIB 為社群維運的免費服務,穩定性無商業保證,需做好
  逾時與錯誤降級,不可假設一定可用。
- **不適用於 podcast**:2026-08-04 已確認專案目前完全無 podcast 概念
  (`Track` model 無 type/kind 欄位、程式庫內無任何 podcast 相關程式碼)。
  即使未來加入 podcast,線上歌詞查詢邏輯也不能直接套用——podcast 沒有
  「歌詞」這個概念,LRCLIB 等歌詞庫不會收錄口語內容,同步文字需求應該是
  逐字稿(ASR/transcription),與本計畫的「查詢既有歌詞庫」是完全不同的
  技術路徑,應另立計畫處理,不併入本檔案的分期。
- **配對品質**:title/artist 命名差異(如「(Live)」「feat.」等後綴)可能
  導致查無結果或誤配,v1 先用最基本的字串比對,配對品質不佳再迭代
  (例如正規化字串、模糊比對分數)。
- **版權**:LRCLIB 本身即以「合法免費開放歌詞庫」定位運作,套用其回傳內容
  風險與現有手動匯入相當(使用者自行取得歌詞檔案),不額外引入新風險。
