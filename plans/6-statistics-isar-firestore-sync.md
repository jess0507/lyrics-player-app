# 統計改存 Isar + 同步 Firestore（users/{uid}）

狀態：**已由 plan 26 取代**（2026-09-03 起雲端備份改存使用者自己的 Google Drive，
見 `plans/26-google-drive-backup.md`；Isar 本機儲存的部分仍有效）。
原狀態：已實作（2026-06-12 決策記錄並完成實作，見文末「實作記錄」）。
影響範圍：`lib/features/profile/statistics/`、`lib/features/player/playback_controller.dart`、
`lib/shared/providers/settings_controller.dart`、`pubspec.yaml`、`firestore.rules`、`android/build.gradle.kts`
相關：`tasks/account-deletion-cloud-functions.md`（刪除帳號已涵蓋 `users/{uid}` 遞迴刪除）

## 背景 / 問題

- 統計（`statistics.data`）目前以 JSON 存在 SharedPreferences（`statistics_service.dart`），
  資料只在本機，清資料或換機即消失。
- Isar 先前只服務音樂庫，音樂庫改 MediaStore 掃描後整套移除；
  既有待辦是「保留 Isar 另作資料儲存層」（見 memory `impl-decisions`），本任務即重新引入的第一個用途。
- 帳號系統（Firebase Auth）已就緒，但雲端尚無任何使用者資料。

## 結論（設計決策）

1. **統計本體改存 Isar，且只存 per-track 記錄**：取代 prefs 的 `statistics.data`。
   每首歌一筆（trackId / title / playCount / listenMs），**不存總計**——
   總計與排行皆於讀取時由 per-track 加總導出，本機與雲端結構對稱。
2. **同步到 Firestore，節流一天**：本機記錄**上次同步時間**，距上次 **> 1 天**才上傳；
   且**自上次同步後無任何變更就不上傳**（省免費額度寫入量）。
   每次上傳同時把 **`updatedAt`（server timestamp）寫進 Firestore**。
3. **Firestore 結構：`users/{uid}/`** 儲存使用者資料：
   - 個人化設定（locale / themeMode / seedColor，對應 `SettingsController`）
   - 統計（每首歌播放次數、播放時間；**總計不另存雲端，由 tracks 加總導出**）
   - 注意：collection 名是 **`users`**（複數），須與 Cloud Functions `_delete_user_data` 一致。
4. **未登入者不同步**：統計照常寫 Isar，僅登入後才上傳（uid 來自 Auth）。
5. **上傳為主、登入時還原**：日常為單向上傳（備份）；換機或重裝後登入時，
   若本機沒有資料則從 Firestore 還原統計與設定（詳見同步策略「下載 / 還原」）。

## Firestore 文件結構與欄位定義

```
users/{uid}                     # 使用者根文件
  ├─ schemaVersion: 1
  ├─ settings:   { locale, themeMode, seedColor }
  ├─ tracks:     { <trackId>: { title, playCount, listenMs } }
  └─ updatedAt:  <server timestamp>
```

**本機（Isar）與雲端皆不存統計總計**（totalPlayCount / totalListenMs）——
皆可由 per-track 記錄加總導出，不存即不會有「總計與明細對不上」的一致性問題。
（已知邊角：prefs 遷移來的**舊資料只有全域時長**、攤不進 per-track，
遷移時直接捨棄，本機與雲端皆不再有此數字。可接受。）

### 欄位定義

| 欄位 | 型別 | 來源 | 說明 |
| --- | --- | --- | --- |
| `schemaVersion` | int | 常數 | 目前為 `1`。日後欄位結構變動時遞增，還原端據此判斷相容性。 |
| `settings.locale` | string \| null | `SettingsState.locale` | 編碼同 prefs：`languageCode` 或 `languageCode_countryCode`（如 `zh_TW`）；`null` = 跟隨系統。 |
| `settings.themeMode` | string | `SettingsState.themeMode` | `ThemeMode.name`：`system` / `light` / `dark`。 |
| `settings.seedColor` | string | `SettingsState.seedColor` | `AppColorSeed` 的 name。還原時未知值 fallback 預設色。 |
| `tracks.<trackId>` | map | `TrackStatEntity` | key 為 MediaStore ID（字串、裝置綁定，見下方注意）。 |
| `tracks.<trackId>.title` | string | `TrackStatEntity.title` | 顯示標題；跨機聚合的對齊依據。 |
| `tracks.<trackId>.playCount` | int | `TrackStatEntity.playCount` | 該曲累計播放次數。 |
| `tracks.<trackId>.listenMs` | int | `TrackStatEntity.listenMs` | 該曲累計聆聽時長，毫秒。 |
| `updatedAt` | timestamp | `FieldValue.serverTimestamp()` | 最後同步時間（server 時鐘），每次上傳必寫。 |

- 時間量一律**毫秒 int**（與本機 `totalListenMs` 一致），不用 Firestore duration 概念。
- 還原端讀取一律容錯：缺欄位給預設值、未知 enum 字串 fallback（同現有 `fromJson` 風格）。

- 寫入用 **`set()` 整份覆寫（不帶 merge）**：本文件所有欄位都由同步一次產出，
  覆寫才能保證雲端 = 單一裝置的完整快照（merge 會讓 `tracks` 變成多裝置聯集，
  重設也清不掉舊條目）。
  日後若此文件加入非同步產出的欄位，再改為「同步欄位整組覆寫」的寫法。
- `tracks` 先用 map 欄位（單文件 1MB 上限，數千首內安全）；若曲庫極大再改 subcollection
  `users/{uid}/tracks/{trackId}`（改了要同步調整 `_delete_user_data` 的註解認知——遞迴刪除已涵蓋）。
- **trackId 是 MediaStore ID，裝置綁定**：換裝置 ID 會不同，title 一併上傳即為此因；
  跨機合併（若做）需以 title/metadata 對齊，不能靠 ID。

## 同步策略

### 本機狀態

- `lastSyncAt`：上次成功上傳的時間，上傳成功才更新。
- `lastModifiedAt`：統計或設定每次寫入時更新（`recordPlay` / `addListenTime` / 設定變更）。
- 兩者存本機（Isar 或 prefs），與統計資料同生命週期。

### 觸發時機

- **App 啟動完成**：主要觸發點，跑一次同步判斷。
- **登入成功當下**：視為立即觸發一次（新登入使用者雲端還沒資料，不必等一天；
  此時若 `lastModifiedAt > lastSyncAt` 即上傳）。
- 不做前景計時器、不在每次播放後觸發——節流粒度是「天」，啟動時檢查已足夠。

### 上傳條件（全部成立才上傳）

1. 已登入（Auth 有 uid）。
2. `lastModifiedAt > lastSyncAt`——**沒有變更就不上傳**。
3. `now - lastSyncAt > 1 天`（登入成功當下的觸發不受此條限制）。

### 執行與失敗處理

- 上傳內容：settings + tracks 一次 `set()` **整份覆寫**單一文件
  `users/{uid}`，附 `updatedAt = FieldValue.serverTimestamp()`（不可信任本機時鐘）。
- 上傳成功 → 更新本機 `lastSyncAt`；失敗（離線、權限、逾時）→ 靜默略過、不重試佇列，
  `lastSyncAt` 不動，下次啟動自然再試。
- 同步全程不阻塞 UI、不顯示錯誤給使用者（背景備份性質）。

### 下載 / 還原（換機、重裝）

- **時機**：登入成功當下（上傳觸發之前）先讀一次 `users/{uid}`。
- **條件**（2026-06-12 改版）：登入時**一律以雲端為準整份還原**，不看本機狀態。
  未登入期間累計的本機資料視為「使用者不想保存」，登入當下直接被雲端覆寫——
  心智模型是「要保存就登入；登入時先拿回雲端資料」。仍**完全避免雙向合併**。
  同一次登入流程中：雲端有文件就還原，沒有才走上傳判斷，兩者互斥。
  （原始版本只在本機無資料且從未同步時才還原，已棄用。）
- **還原內容**：settings（locale / themeMode / seedColor）套用到 `SettingsController` 並落地 prefs；
  tracks 整份寫入 Isar 即完成（總計本來就是讀取時導出，無需重建）；
  還原後 `lastSyncAt = now`、`lastModifiedAt` 不動
  （還原不算本機變更，避免馬上又觸發上傳）。
- **trackId 跨機不一致的處理**：雲端 entries 原樣還原（保留舊裝置的 trackId + title）。
  新裝置上播放同一首歌會以新 trackId 另起 entry，造成同曲兩筆——
  解法是**顯示層以 title 聚合**：`topTracks()` 把相同 title 的次數加總後再排序。
  資料層不做 ID 改寫或 title 合併（保持上傳/還原為無損搬運）。
- 雲端沒有文件（首次使用）→ 跳過還原，直接走上傳判斷。

### 衝突與邊界

- **多裝置**：採 **last-write-wins**（2026-06-12 決策）——雲端永遠是「最後同步那台」的
  完整快照，**不合併、不加總**：A 機 100 次 + B 機 50 次，雲端只會是其中一台的數字。
  換機還原也只拿得到最後同步那台的歷史。此為已知限制；
  若日後要全帳號加總，再改增量上傳（`FieldValue.increment`）方案。
- **登出**：本機統計保留、停止上傳；`lastSyncAt` / `lastModifiedAt` 不清。
  再次登入（同帳號或換帳號）時依登入還原規則：該帳號雲端有文件就整份覆寫本機，
  沒有才把本機上傳到該 uid 下；其他帳號的雲端資料不動。
- **統計重設（reset）**：先跳**確認 dialog** 警告使用者（說明本機與雲端備份都會刪除），
  使用者再次選擇重設才執行：清空本機 + **立即刪除遠端統計**（不等下次同步班次）。
  - 遠端刪法：沿用整份覆寫語意——立刻 `set()` 上傳「tracks 清空、settings 維持現值」的快照，
    並更新 `lastSyncAt`。
  - 未登入：只清本機，dialog 文案不提雲端。
  - 已登入但離線／上傳失敗：本機照清、`lastModifiedAt` 已更新，
    雲端等下次同步以空狀態覆寫達成最終一致（dialog 不需擋）。
- **刪除帳號**：雲端由 Cloud Function 遞迴刪 `users/{uid}`（既有機制）；
  本機資料與登出同規則處理。

## 步驟

1. **重新引入 Isar**：`isar: ^3.1.0+1` + `isar_flutter_libs` + `isar_generator`，
   `isarProvider` 於 main() 注入。⚠️ 沿用既有陷阱解法：isar_flutter_libs 未宣告 AGP namespace，
   `android/build.gradle.kts` 的 subprojects namespace 補丁仍在（為 on_audio_query 保留），確認可共用。
2. **統計 schema 與遷移**：`TrackStatEntity`（@collection，trackId 唯一索引 replace），
   欄位 trackId / title / playCount / listenMs，**一首歌一筆、無總計 collection**。
   首次啟動把 prefs `statistics.data` 的 `perTrackCount` + `trackTitles` 匯入 Isar
   後移除舊 key（全域 `totalListenMs` 攤不進 per-track，捨棄）。
   `StatisticsController` 改讀寫 Isar（同步 API，Notifier 維持同步），
   `StatisticsData` 變成由 per-track 記錄導出的 view（總計欄位改為 getter 加總）；
   `recordPlay` / `addListenTime` 呼叫點（`playback_controller.dart`）介面不變，
   但 `addListenTime` 需多帶 trackId 以累計 per-track 時長。
3. **加 `cloud_firestore` 依賴 + SyncService**：依 CLAUDE.md 一檔一 provider，
   sync service 與其 provider 獨立成檔（`lib/core/sync/` 之類），不塞進 statistics_service。
4. **個人化設定上傳**：設定變更不即時上傳，跟統計同一班次（一天一次）一起 merge 寫入。
5. **登入時還原**：SyncService 實作下載 / 還原（見同步策略），掛在登入成功事件上；
   `topTracks()` 改以 title 聚合，吸收跨機 trackId 不一致。
6. **重設確認 dialog**：統計頁 reset 改為先跳警告 dialog（本機 + 雲端都會刪），
   確認後清本機並立即上傳歸零快照（見「衝突與邊界」）。
   新增 l10n key（警告標題／內文分登入與未登入兩版／確認鈕），
   照慣例 en + zh_TW + zh_CN，其餘語系 fallback；**待辦：補進 Google Sheet**。
7. **Firestore security rules**：開本人限定規則（`request.auth.uid == uid` 才可讀寫 `users/{uid}/**`），
   `firestore.rules` 收進 repo + `firebase.json`，跟 CICD 一起部署
   （account-deletion task §後續 已預告此事，於本任務落實）。
8. 驗證：`flutter analyze`、`flutter test`、實機 Gradle build
   （Isar 重新引入後原生依賴需實機驗，先前移除時就欠這項）。

## 實作記錄（2026-06-12）

依上述設計實作完成，檔案落點與決策細節：

- **新檔**：`lib/core/storage/isar_service.dart`（openIsar + isarProvider，沿用舊版寫法）、
  `lib/features/profile/statistics/track_stat_entity.dart`（+ 產生的 `.g.dart`）、
  `lib/core/sync/sync_state_store.dart`（lastSyncAt / lastModifiedAt，存 prefs
  key `sync.lastSyncAt` / `sync.lastModifiedAt`）、
  `lib/core/sync/sync_service.dart`、`firestore.rules`、`test/statistics_data_test.dart`。
- **觸發實作**：SyncService 由 `app.dart` watch 一次啟動，監聽 authStateChanges——
  **首個事件視為「App 啟動」**（上傳判斷、節流一天），其後 null → user 的轉變
  才視為「登入成功當下」（先還原判斷、上傳不節流）。
- **介面變更**：`StatisticsController.addListenTime(Track, Duration)` 多帶曲目；
  `AudioPlayerService` 新增 `currentIndex` getter 供 5 秒取樣定位目前曲目。
  `StatisticsData` 改為 `List<TrackStatEntity>` 的 view，總計皆 getter 加總，
  `topTracks()` 以 title 聚合。
- **還原不算變更的落實**：`SettingsController.restoreFromRemote` /
  `StatisticsController.restoreFromRemote` 寫入但不 markModified；
  一般 setter（setLocale 等）與 recordPlay / addListenTime / reset 都會 markModified。
- **prefs 遷移**：於 `StatisticsController.build()` 執行（讀 `statistics.data`、
  匯入後移除 key、視為本機變更）；SyncService 上傳判斷前先 read 統計 provider，
  確保遷移先於條件判斷。
- **l10n**：新增 `statistics_reset_title` / `statistics_reset_message`（未登入版）/
  `statistics_reset_message_cloud`（登入版）/ `statistics_reset_confirm`，
  en + zh_TW + zh_CN；取消鈕沿用既有 `common_cancel`。**待辦：補進 Google Sheet。**
- **CICD**：沿用 `.github/workflows/firebase-functions-deploy.yml`，
  deploy 改 `--only functions,firestore:rules`，paths 加入 `firestore.rules`；
  `firebase.json` 增 `firestore.rules` 設定。
- **analysis_options**：排除 `**/*.g.dart`——Isar 3 產生碼使用自身標為
  experimental 的 API，新版 analyzer 會報 12 個 `experimental_member_use`。
- **驗證結果**：`flutter analyze` 無 issue、`flutter test` 5 項全過
  （含新增的 StatisticsData 加總 / title 聚合單元測試）、
  `flutter build apk --debug` 成功（cloud_firestore 6.5.0、isar_flutter_libs
  namespace 補丁如預期可共用），debug APK 安裝至 Android 模擬器啟動正常
  （Isar 開啟成功、未登入時同步靜默不動作、無例外）。
  尚未驗：登入帳號後的實際上傳 / 還原（需在實機登入測試帳號操作一輪）。

## 增補：統計改為每日 × 每首歌記錄（2026-06-12）

為時間軸圖表與「每天聽了哪些歌、各聽幾次／多久」加入按天明細。
依「**不需要記錄總和**」的決策，唯一儲存的就是每日明細，
原 per-track 累計 collection（TrackStatEntity）一併退役——
累計總量本身就是「被記錄的總和」，改由每日記錄加總導出。

- **唯一 collection `DailyTrackStatEntity`**（`daily_track_stat_entity.dart`）：
  一天一首歌一筆，`day`（本地日期 `yyyy-MM-dd`）+ `trackId` 複合唯一索引
  （replace），欄位另有 `title` / `playCount` / `listenMs`。
- **一切導出**：`StatisticsData` 只持有 `days`（依日期升冪）；
  `totalPlayCount` / `totalListenMs` 為跨日加總 getter，
  `topTracks()` 跨日 + title 聚合（排行不變），新增
  `dailyTotals()`（依日聚合，軸線圖資料點）與 `allTracks()`（期間內全曲明細）。
  統計頁只用導出 getter，無須改動。
- **期間子集 API**：`onDay` / `inMonth` / `inYear`（吃 `DateTime`）回傳
  過濾後的 `StatisticsData`，所有導出 getter 自動只算該期間
  （day key 定長 `yyyy-MM-dd`，prefix 比對即可取日／月／年）。
  例：當日明細 = `stats.onDay(date).allTracks()`。
- **state 增量更新**：寫入後把單筆 upsert 套進既有 state，
  不再每次全量重讀 Isar（`addListenTime` 每 5 秒取樣一次，
  資料量大時全量重讀划不來）；全量 `_load()` 只剩 build 與雲端還原兩處。
- **累計時機**：`recordPlay` / `addListenTime` upsert（今天, trackId）一筆，
  日期取裝置本地時區（`StatisticsController.dayKey`）。
- **TrackStatEntity 整個移除**（決策：「不需要 TrackStatEntity」）：
  entity / schema / 檔案皆刪，不做 Isar 端遷移——該 collection 是當天才實作、
  未發布，既有資料只在開發機，直接捨棄（Isar 開檔時 schema 未註冊的
  collection 會被清掉）。
- **prefs 遷移保留**：`statistics.data`（已發布的舊版格式）→ 遷移當日的
  每日記錄（掛在遷移當日，攤不進真實日期為已知取捨）。
- **同步 schema v2**：`days: { <yyyy-MM-dd>: { <trackId>: { title, playCount,
  listenMs } } }` 取代 v1 的 `tracks`，**舊 tracks 直接棄用**：
  v1 從未實際上傳過（上線前即改版、雲端無 v1 文件），
  還原端只 decode `days`、不留 v1 相容路徑。
  文件大小：天數 × 當日曲數，重度使用數年內仍遠低於 1MB 上限；
  若將來要瘦身，再加「保留最近 N 天 + 截斷」即可（總量會跟著少算，屆時再議）。
- 驗證：`flutter analyze` 無 issue、`flutter test` 8 項全過
  （總計導出 / topTracks 聚合 / tracksOn / dailyTotals / dayKey）。
  UI 圖表（軸線圖）為後續任務，本次僅落資料層。

## 增補：歌詞備份（sync schema v5，2026-07-13）

推翻 v1「歌詞純本機不同步」決策（原因是體積與版權疑慮、換機重匯即可）：
播放清單同步與 trackId 指紋化完成後，歌詞成為唯一換機會遺失的使用者資料，
決定一併納入備份。

- **子集合而非主文件欄位**：歌詞原文一首可達數 KB～1 MiB（匯入上限），
  塞進 `users/{uid}` 主文件會撞單一文件 1 MiB 上限，
  改存 `user/{uid}/backupLyrics/{trackId}` 逐曲一份文件
  （欄位：`title` / `format` / `source` / `content` / `addedAt`）。
  單曲內文 > 900 KiB 者跳過不上傳（留欄位餘裕，避免整批失敗）。
- **主文件升 v5**：v5+ 的文件以子集合為歌詞權威來源（空集合也整份覆寫
  本機）；還原 v4 舊文件時不動本機歌詞，還原後接續的上傳判斷把
  存量歌詞補推、文件順勢升 v5（`_onSignedIn` 還原成功後不再提早 return）。
- **獨立變更時戳**：統計每次播放都在變，若共用 `lastModifiedAt` 每個班次
  都會全量重推歌詞（讀雲端 ID + 逐曲重寫）。`SyncStateStore` 另設
  `lyricsModifiedAt` / `lastLyricsSyncAt`，只在歌詞真的變更後推送；
  推送失敗只重試歌詞（主文件重寫冪等無妨）。
- **寫入端集中在 LyricsRepository**：`save` / `deleteByTrackId`（有真的刪到）
  呼叫 `markLyricsModified`，匯入 / 自動產生 / 自動對時 / 刪除全都經過它。
- **變更當下立即推送**：`markLyricsModified` 先寫時戳再發事件
  （`SyncStateStore.lyricsModifiedEvents`），SyncService 監聽後立即跑
  `_upload`，不等下次班次。走事件而非 repository 直呼 SyncService，
  避免 feature → core/sync 的循環 import；未登入時只留待推記號，
  登入後班次補推。失敗沿用既有語意：靜默略過、記號不動、下個班次重試。
- **存量遷移**：本功能上線前匯入的歌詞沒有變更記號，`SyncService._init`
  一次性補記（兩個歌詞時戳皆 null 且本機有歌詞才補），
  讓首個班次推上雲端。全新安裝（本機無歌詞）不觸發，
  避免登入還原前誤刪雲端歌詞。
- **推送語意與主文件一致**：全量快照、last-write-wins——先讀雲端文件 ID，
  刪除本機沒有的、整批重寫本機所有歌詞（WriteBatch 每 400 個操作分批）。
- **還原後 UI**：`trackLyricsProvider` 不走 Isar watch，
  還原完成後 `ref.invalidate` 整個 family 觸發重讀。
- `firestore.rules` 既有的 `users/{uid}/{document=**}` 規則已涵蓋子集合，
  不需改動。
- **檔案組織（同日重構）**：各領域的編解碼與還原拆至 `core/sync/` 下
  一領域一檔一 provider——`settings_sync.dart` / `statistics_sync.dart` /
  `playlists_sync.dart` / `lyrics_sync.dart`（推送 / 待推判斷 / 存量補記
  也在此）；`sync_service.dart` 只留調度（觸發時機、變更判斷、
  schemaVersion 與主文件組裝）。行為不變。
- 驗證：`flutter analyze` 無 issue、`flutter test` 29 項全過。

## 增補：播放清單變更即時上傳（節流 5 分鐘，2026-07-13）

播放清單操作（建立 / 改名 / 刪除 / 加減曲 / 排序）不再只等 App 啟動 /
回前景的班次，變更當下就觸發上傳，但以 5 分鐘節流控制寫入頻率：

- **事件通道**：`markPlaylistModified` = `markModified`（主文件變更時戳
  照舊共用）+ 發 `SyncStateStore.playlistModifiedEvents` 事件；
  PlaylistRepository 六個寫入點全數改呼叫它。統計每次播放都會
  `markModified`，所以不能共用該時戳當觸發源，需要專屬事件。
- **節流語意（leading + trailing）**：窗外首次變更立即上傳；5 分鐘窗內
  的後續變更合併為窗末一次（Timer 排定）。觸發走 `_maybeUpload`，
  期間若已被回前景等其他班次推掉就自動跳過。
- **上次觸發時間存記憶體**（App 重啟歸零）：重啟後首次變更一律立即推，
  跨重啟最壞情況只是多推一次快照，可接受。
- 未登入時不排程，留著變更時戳由登入後的班次補推；登出後 Timer 到期
  也不上傳（`_uploadForCurrentUser` 以當下登入者判斷）。
- 驗證：`flutter analyze` 無 issue、`flutter test` 29 項全過。
