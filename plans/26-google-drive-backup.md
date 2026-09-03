# 備份改存使用者自己的 Google Drive(取代 Firestore 同步)

狀態:**已實作**(2026-09-03 起草並完成實作,見文末「實作記錄」)。
影響範圍(預計):`lib/core/sync/`(整組重寫)、`lib/core/auth/`(共用 GoogleSignIn)、
`lib/features/profile/backup/`(骨架頁補上內容)、`lib/features/profile/account/widgets/`
(移走「立即同步」)、`lib/features/profile/statistics/statistics_page.dart`、
`lib/features/profile/profile_page.dart`(備份入口不再要求登入)、`lib/l10n/`、
Google Cloud Console(啟用 Drive API、OAuth 同意畫面加 scope)。
相關:`plans/6-statistics-isar-firestore-sync.md`(Firestore 同步的原始設計,本計畫取代之)、
`plans/25-path-based-track-id.md`(trackId 跨機語意)、commit `7ec171e`(暫停雲端同步)。

## 背景 / 問題

- 設定 / 播放清單 / 統計 / 歌詞四個領域目前的雲端備份走 Firestore `user/{uid}/…`
  (plan 6 → sync v7),2026-09-03 已在 `SyncService._init` 整段註解停用,
  現在資料只寫本機 Isar。
- 資料放在 App 自己的 Firestore:寫入量吃免費額度、單文件 1 MiB 上限
  (歌詞得逐曲拆文件、統計得按月分桶)、刪帳號要靠 Cloud Function 遞迴清、
  隱私上使用者的資料實際掌握在 App 方。
- 目標:備份檔存進**使用者自己的 Google Drive**,App 只借 OAuth 授權讀寫;
  App 方不再持有使用者的備份資料。

## 結論(設計決策)

### 1. 登入與備份脫鉤:**不是只能 Google 登入**

| 概念 | 用途 | 身分來源 |
| --- | --- | --- |
| **帳戶登入**(Firebase Auth) | 歌詞 AI(Cloud Functions / Cloud Run 任務、用量上限、`user/{uid}/lyrics` 任務結果)、刪帳號 | Email / 手機 OTP / Google / Facebook,**維持不變** |
| **備份連結**(Google Drive 授權) | 備份與還原四個領域的資料 | `google_sign_in` 取得的 Google 帳號 + `drive.appdata` scope |

- 備份頁多一個「連結 Google 雲端硬碟」動作,任何使用者(含 Email / 手機 /
  Facebook 登入者,**甚至完全沒登入 Firebase 的人**)都能連結一個 Google 帳號來備份。
  備份用的 Google 帳號**可以跟登入帳號不同**。
- 已用 Google 登入 Firebase 的人:連結時只走 `requestScopes([drive.appdata])`
  增量授權,不再跳帳號選擇器,只多一頁「允許存取雲端硬碟 App 資料」的同意畫面。
- 「更多 → 備份」入口**不再要求 Firebase 登入**(移除 `_ensureSignedIn` 關卡與
  `profile_backup_need_login` 文案),改由備份頁自己顯示「尚未連結」狀態。
- 捨棄的替代方案:**改成只留 Google 登入、登入即備份**。理由:會砍掉現有
  Email / 手機 / Facebook 登入者;且在登入當下就要 Drive 同意畫面,
  對只想用歌詞 AI 的人是多餘的權限請求。

### 2. 存放位置:Drive `appDataFolder`(scope `drive.appdata`)

- 檔案放在 Drive 的 **應用程式資料夾**:使用者在 Drive 檔案列表看不到,
  但可在「Drive 設定 → 管理應用程式」看到 Seek Player 佔用大小並一鍵刪除;
  其他 App 讀不到;使用者不會誤搬 / 誤刪 / 改名。
- `drive.appdata` 是 Google 列為 **non-sensitive** 的 scope:OAuth 同意畫面
  不需送審驗證(`drive` 全域 scope 才是 restricted)。
- 捨棄的替代方案:`drive.file` + 在「我的雲端硬碟」建可見的 `Seek Player/` 資料夾。
  好處是使用者能自己拿走 `lyrics.json`;壞處是要靠名稱找資料夾(可能被改名、
  重複建立、搬走),每次同步多一次查找,錯誤情境多很多。日後若要「匯出」
  給使用者看,另做「匯出成檔案 → 系統分享」比較直接,不混進備份機制。

### 3. 檔案結構:一領域一檔,沿用四領域各自獨立的推 / 拉語意

```
appDataFolder/
  ├─ settings.json      ← SettingsController.toRemoteMap()
  ├─ playlists.json     ← { "playlists": [ {id, name, isFavorites, isRecentlyPlayed,
  │                         createdAt, trackIds, recentlyPlayed:[{trackId, playedAt}]} ] }
  ├─ statistics.json    ← { "months": { "yyyy-MM": { "days": {day: {trackId: {title,
  │                         playCount, listenMs}}}, "playCount", "listenMs" } } }
  └─ lyrics.json        ← { "lyrics": [ {trackId, title, format, source, content,
                            updatedAt} ] }
```

- 每個檔案的 `appProperties: { "schemaVersion": "1" }`(Drive 的自訂屬性,
  list 一次就拿得到,不用先下載)。Drive 格式的版號從 **1** 重新起算,
  與 Firestore 的 v7 無關(兩者不互通)。
- **時戳用 Drive 回傳的 `modifiedTime`**(伺服器時鐘),對應原本
  `setting/0` 裡的 `settingUpdatedAt` 等四個 `FieldValue.serverTimestamp()`;
  本機端 `SyncStateStore` 的四個 `*ModifiedAt` **原封不動**。
  推 / 拉判斷邏輯(`_shouldPush` / `_shouldPull`)一字不改,只是 remote 時戳來源換掉。
  → 不需要另外的 `manifest.json`;一次 `files.list` 就拿到四個檔的 id、modifiedTime、
  schemaVersion。
- 時間量一律毫秒 int、還原一律容錯(缺欄位給預設值、未知 enum fallback),
  與現行 `*Sync` 的解碼風格相同;把現有四個 `_Remote*Decode` extension 改成
  吃 JSON Map 即可,`restoreFromRemote` / `toRemoteMap` 等 repository 介面**不動**。
- 大小:Drive 單檔上限 5 TB,不再有 1 MiB 問題——`LyricsSync` 的 900 KB 跳過、
  統計按月分桶、WriteBatch 400 筆分批**全部拿掉**;統計仍按月分桶只是 JSON 結構
  (沿用既有 `monthlyTotals()` 輸出),不是因為大小限制。
  歌詞數千首 × 數 KB ≈ 數 MB,先存 plain JSON;若實測 > 10 MB 再加 gzip
  (`dart:io` `GZipCodec`,檔名 `lyrics.json.gz`),本計畫不做。

### 4. 觸發時機與方向:與現行相同,只把「登入」換成「連結」

| 時機 | 動作 |
| --- | --- |
| 連結成功當下 | `_onLinked`:先 `_restoreFromDrive`(四領域各自比時戳,遠端較新才還原),再 `_maybeUpload` |
| App 啟動 | `signInSilently()` 取回 Google session;成功 → `_maybeUpload` |
| App 回前景(`AppLifecycleListener.onResume`) | `_maybeUpload` |
| 備份頁「立即備份」 | `syncNow()`:四領域仍各自依 `_shouldPush` 判斷 |
| 備份頁「從雲端硬碟還原」(新) | 確認對話框後**強制**四領域全部還原(不比時戳),供換機 / 誤刪後手動救回 |
| 統計重設 | `uploadAfterReset()` 語意不變:立即推統計歸零快照 |
| 解除連結 | `GoogleSignIn.disconnect()`(撤銷授權)+ 清本機連結狀態;Drive 上的檔案**保留**(再連結同帳號可直接還原) |
| 刪除雲端備份(新) | 確認後刪除 appDataFolder 四個檔;不解除連結 |

- 多裝置仍是 **last-write-wins**、不合併;各領域獨立比對(統計每次播放不會連帶重推歌詞)。
- 失敗處理同現行:離線 / 逾時靜默略過、`reportError` 上報、下次班次再試;
  唯 **401 / 403** 特別處理(見「錯誤處理」)。

### 5. Drive 存取:自己用 `http` 打 REST,不加 `googleapis`

只需五個端點,手寫一個 ~150 行的 client 即可,避免拉進 `googleapis`
(專案既有原則:歌詞 LRCLIB 也只用 `http`):

| 動作 | 請求 |
| --- | --- |
| 列出 | `GET /drive/v3/files?spaces=appDataFolder&fields=files(id,name,modifiedTime,appProperties)&pageSize=100` |
| 建檔(僅 metadata) | `POST /drive/v3/files` body `{name, parents:["appDataFolder"], appProperties}` → 回 `id` |
| 寫內容 | `PATCH /upload/drive/v3/files/{id}?uploadType=media`,body 為 JSON bytes,回應含 `modifiedTime` |
| 下載 | `GET /drive/v3/files/{id}?alt=media` |
| 刪除 | `DELETE /drive/v3/files/{id}` |

- 上傳拆「建檔 + 寫內容」兩步而不用 `uploadType=multipart`:省掉手刻 multipart 邊界;
  建檔只在該檔第一次出現時做一次,之後都是一個 PATCH。
- Authorization header 來自 `GoogleSignInAccount.authHeaders`
  (google_sign_in 6.x 會自動換新 access token)。
- 捨棄的替代方案:`googleapis` + `googleapis_auth`。型別齊全,但整包依賴大、
  且仍要自己包一個帶 header 的 `http.Client`,對五個端點不划算。

### 6. `google_sign_in` 維持 6.x,單一共用 instance

- 目前 lock 在 6.3.0。7.x 是整套改寫(`GoogleSignIn.instance` / `authorizationClient`),
  會連帶改 `AuthService.signInWithGoogle`,本計畫**不升**;之後若升 7.x,
  增量授權改用 `authorizationClient.authorizeScopes` 即可,對外介面不變。
- Android 端 plugin 是原生單例,**多個 `GoogleSignIn(...)` 實例會互相蓋掉 scopes**,
  所以抽成一個 `googleSignInProvider`(預設 scopes,不含 Drive),
  `AuthService` 與 Drive 連結共用;Drive scope 一律用 `requestScopes` 增量加。
- **`AuthService.signOut()` 改成只登出 Firebase**,不再連帶 `_googleSignIn.signOut()`
  ——否則登出帳戶會順手把備份連結砍掉。代價:下次用 Google 登入 Firebase 時
  不會跳帳號選擇器、直接沿用同一個 Google 帳號;可接受(要換帳號可先解除備份連結)。
- 連結狀態持久化:prefs `backup.driveLinked`(bool)+ `backup.driveEmail`(顯示用)。
  啟動時 `signInSilently()`;失敗(使用者在 Google 端撤銷、token 失效)→ 顯示
  「需要重新連結」,不自動跳同意畫面。

### 7. 不做 Firestore → Drive 的一次性搬遷

Firestore 同步已停用;雲端上的 `user/{uid}/setting|playlist|monthlyStats` 只是
「最後同步那台裝置」的快照,那台裝置本機就有同一份資料,第一次連結 Drive 時上傳
本機即等於搬遷。Firestore 這三個子集合之後由 `delete_account_data` 既有遞迴刪除
自然清掉,不另寫清理。
`user/{uid}/lyrics/{trackId}` **保留**:它是歌詞 AI 任務結果的投遞點
(`lyrics_pending_sync_service` / `track_lyrics_provider` 讀它),不是備份;
只是 `LyricsSync.push` 那段「刪雲端多餘歌詞文件」隨 Firestore 同步一起消失。

## 錯誤處理

| 狀況 | 處理 |
| --- | --- |
| 離線 / 逾時 / 5xx | 靜默略過,`lastSyncAt` 不動,下次班次再試(同現行) |
| 401 | `clearAuthCache()` 後重試一次;再失敗 → 標記「需要重新連結」 |
| 403 `insufficientPermissions` / `accessNotConfigured` | 前者 = scope 被撤銷 → 標記「需要重新連結」;後者 = Cloud 專案沒開 Drive API,開發期錯誤,直接 `reportError` |
| 403 `storageQuotaExceeded` | 使用者 Drive 滿了 → 備份頁顯示對應文案(`backup_drive_full`),不重試 |
| 遠端 `schemaVersion` > 本機 | 跳過該領域還原與上傳(同現行「App 尚未升級」邏輯),逐檔判斷 |
| 同名檔案多份(理論上不會,除非上傳中斷後重試) | list 時同名取 `modifiedTime` 最新者,其餘刪除 |

備份全程不阻塞 UI;只有使用者主動按的「立即備份 / 還原 / 刪除」才 toast 回報結果。

## 檔案與 provider 配置

沿用 `lib/core/sync/`,嚴格一檔一 provider(CLAUDE.md):

```
lib/core/auth/
  google_sign_in_provider.dart        googleSignInProvider(共用 GoogleSignIn 實例,預設 scopes)
  auth_service.dart                   改吃 googleSignInProvider;signOut 不再登出 Google
lib/core/sync/
  google_drive_account.dart           GoogleDriveAccount:link / unlink / restoreSession / authHeaders
                                      + googleDriveAccountProvider
  google_drive_link_state.dart        DriveLinkState(notLinked / linked(email) / needsRelink)
                                      + driveLinkStateProvider(Notifier,供備份頁與 SyncService)
  google_drive_client.dart            GoogleDriveClient(五個 REST 端點,appDataFolder 專用)
                                      + googleDriveClientProvider
  drive_backup_file.dart              DriveBackupFile(name, id, modifiedTime, schemaVersion)純模型
  settings_backup.dart                SettingsBackup:encode() / decode();push / restore 吃 client
  playlists_backup.dart               PlaylistsBackup(同上)
  statistics_backup.dart              StatisticsBackup(同上,含 ensureMigrated)
  lyrics_backup.dart                  LyricsBackup(同上,含 markExistingPending)
  sync_google_drive_service.dart      新檔(舊 sync_service.dart 刪除,git 上不混成同檔 diff):
                                      監聽 driveLinkState 而非 authStateChanges;
                                      syncToCloud() / syncToLocal() / uploadAfterReset()
  sync_state_store.dart               不動
  ─ 刪除:settings_sync / playlists_sync / statistics_sync / lyrics_sync
lib/features/profile/backup/
  backup_page.dart                    骨架頁補內容(組合以下 widgets)
  providers/
    last_sync_at_provider.dart        自 account/providers 搬來
  widgets/
    drive_link_tile.dart              連結狀態 + 連結 / 解除連結
    backup_now_tile.dart              自 account/widgets/sync_now_button.dart 搬來改名
    restore_tile.dart                 從雲端硬碟還原(確認對話框)
    delete_remote_tile.dart           刪除雲端備份(確認對話框)
lib/features/profile/account/widgets/user_info_view.dart   移除 SyncNowButton
lib/features/profile/profile_page.dart                     backup 入口不再 _ensureSignedIn
```

### 備份頁版面

```
[Google 雲端硬碟]
  ○ 尚未連結                          [連結]
  ● 已連結 jess@gmail.com             [解除連結]
  ⚠ 需要重新連結(授權已失效)          [重新連結]
─────────────────────────────
  ⟳ 立即備份                 上次備份 2026/9/3 16:10
  ⤓ 從雲端硬碟還原            (未連結時 disabled)
  🗑 刪除雲端備份              (未連結時 disabled)
─────────────────────────────
  說明:備份內容為設定、播放清單、播放統計、歌詞;音樂檔案不會上傳。
       備份存在你自己的 Google 雲端硬碟「應用程式資料」區,
       可在雲端硬碟設定 → 管理應用程式 查看或刪除。
```

## 平台 / 後台設定

- **Google Cloud Console(Firebase 專案)**:啟用 **Google Drive API**
  (沒開會 403 `accessNotConfigured`);OAuth 同意畫面 → 資料存取 → 新增
  `https://www.googleapis.com/auth/drive.appdata`。
- Android:沿用 `google-services.json` 既有 OAuth client 與 SHA-1,無需新設定。
- iOS:`GIDClientID` / URL scheme 已在 `Info.plist`,無需新設定。
- 隱私權政策(`about` 頁連結的文件)補一段:備份資料存於使用者 Google Drive
  應用程式資料夾,App 方不持有。

## l10n

新增前綴 `backup_*`(17 個 arb 全部要補,`flutter gen-l10n`):
`backup_drive_section`、`backup_link`、`backup_unlink`、`backup_relink`、
`backup_not_linked`、`backup_linked_as`、`backup_needs_relink`、`backup_now`、
`backup_last_at`、`backup_never`、`backup_done`、`backup_failed`、
`backup_restore`、`backup_restore_confirm`、`backup_restore_done`、
`backup_delete_remote`、`backup_delete_remote_confirm`、`backup_delete_remote_done`、
`backup_drive_full`、`backup_description`。
既有 `account_sync_*` 四個 key 與 `profile_backup_need_login` 移除。

## 步驟

1. **共用 GoogleSignIn**:新增 `googleSignInProvider`;`AuthService` 改注入、
   `signOut()` 拿掉 Google 登出。`flutter analyze`。
2. **Drive 存取層**:`GoogleDriveAccount`(link = `signIn()` 或已登入時 `requestScopes`、
   unlink = `disconnect()`、`restoreSession` = `signInSilently`)、`DriveLinkState` notifier、
   `GoogleDriveClient` 五端點 + 錯誤分類(401/403 子類 / 網路)。
   單元測試:client 以 `MockClient`(`package:http/testing.dart`)驗證請求形狀與錯誤分類。
3. **四領域 codec**:把 `*_sync.dart` 改寫成 `*_backup.dart`,encode/decode 純函式
   (JSON Map ↔ entity),`push` / `restore` 吃 `GoogleDriveClient`。
   單元測試:各領域 encode → decode round-trip、缺欄位 / 壞欄位容錯。
4. **SyncService 重寫**:remote 時戳改讀 `files.list` 的 `modifiedTime`;
   訂閱 `driveLinkStateProvider`;`app.dart` 恢復 `ref.watch(syncGoogleDriveServiceProvider)`;
   新增 `restoreAll()`、`deleteRemote()`。
   單元測試:以記憶體 fake client 驗證推 / 拉方向、schemaVersion 較新跳過、單領域失敗不影響其他。
5. **備份頁 UI**:四個 tile widgets + 頁面組合;帳戶頁移除 `SyncNowButton`;
   `profile_page.dart` 拿掉備份的登入關卡;`statistics_page.dart` 的 `uploadAfterReset` 不動。
6. **l10n**:17 個 arb 補 `backup_*`、刪舊 key,`flutter gen-l10n`、`flutter analyze`。
7. **Cloud Console**:啟用 Drive API、同意畫面加 scope;debug build 實機驗證
   (連結 → 上傳 → 清資料 → 重新連結 → 還原;Email 登入者連結另一個 Google 帳號)。
8. **收尾**:刪除四個 `*_sync.dart`;`plans/6` 標註「已由 plan 26 取代」;
   隱私權政策更新。

## 已知限制 / 留待之後

- 多裝置 last-write-wins 不合併(承襲 plan 6 決策)。
- trackId 跨機語意依 `plans/25`:另一台沒有同路徑的檔,歌詞 / 統計對不上就不顯示。
- 自訂封面(`covers/` 圖檔 + `TrackCoverEntity`)目前本來就不在同步範圍;
  Drive 天生適合放檔案,之後可加第五個領域 `covers/` 目錄,本計畫不做。
- 使用者在 Google 端撤銷授權時,App 要等下一次 API 呼叫拿到 401/403 才知道。

## 實作記錄(2026-09-03)

與上文的偏離:

- **檔名**:`sync_service.dart` 直接刪除、新增 `sync_google_drive_service.dart`
  (class `SyncGoogleDriveService`、provider `syncGoogleDriveServiceProvider`),
  讓 git 上看得出是整組換掉而非同檔大改。
- **備份頁只有兩個動作**:「同步到雲端」(`syncToCloud`,四領域各自依時戳)與
  「同步到本地」(`syncToLocal`,確認後強制全還原)。原規劃的「刪除雲端備份」
  不做——使用者可在 Drive 設定 → 管理應用程式 刪除,備份頁說明文字有寫。
- **連結狀態**拆成 `drive_link_state.dart`(sealed class)與
  `drive_link_controller.dart`(Notifier + `driveLinkStateProvider`),
  一檔一 provider。
- **結果回報**用 `SyncOutcome` enum(`sync_outcome.dart`)取代 bool,
  區分未連結 / 需重新連結 / Drive 已滿 / 雲端無備份 / 失敗。
- **四領域 codec** 抽出 `DomainBackup` 介面(`domain_backup.dart`):各領域只做
  本機 ↔ JSON Map,序列化 / 上傳 / 下載 / 時戳判斷全在 service;encode / decode
  為 static 純函式,單元測試直接打。
- **`upload` 的 metadata PATCH**:既有檔的 schemaVersion 與本機不同時才補一次
  `appProperties` PATCH(`uploadType=media` 無法一併更新 metadata)。
- **Google 登入的帳號選擇器**:原規劃「`signOut()` 不登出 Google」會讓帳戶頁按
  Google 登入時直接沿用舊 session、不跳選擇器(實測被抓到)。改為
  `signInWithGoogle()` 先 `googleSignIn.signOut()` 再 `signIn()`,選擇器每次都出現;
  `GoogleDriveAccount` 以 email 比對連結時的帳號,session 換成別的 Google 帳號時
  視為不可用(`authHeaders` 丟 unauthorized → 標記需重新連結),絕不用錯帳號上傳;
  沒 session 時 `authHeaders` 會先 `signInSilently` 取回。
  錯誤型別搬到 `google_drive_exception.dart`,避免 account ↔ client 循環 import。
- **統計重設警語**(`statistics_reset_message_cloud`)改看 Drive 是否已連結,
  不再看 Firebase 登入。
- **測試**:`test/core/sync/` 五個檔——`DriveBackupFile` 解析、`GoogleDriveClient`
  五端點 / 401 重試 / 403 分類(MockClient)、三個領域 codec round-trip 與容錯。
  `SyncGoogleDriveService` 的推 / 拉決策未寫單元測試(要 Isar + 全套 provider),
  以實機驗證為主。

尚未完成(需手動):

- Google Cloud Console 啟用 **Google Drive API** + OAuth 同意畫面加
  `drive.appdata` scope(沒開會 403 `accessNotConfigured`)。
- 實機驗證:連結 → 同步到雲端 → 重置 → 重新連結 → 同步到本地;
  Email 登入者連結另一個 Google 帳號。
- 隱私權政策補「備份存於使用者自己的 Google Drive」。
