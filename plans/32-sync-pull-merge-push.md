# 32 - 同步改為「先 pull、merge,再 push」(含刪除紀錄)

## 背景與目標

目前 Firestore 同步(`SyncService`)的行為:

- 已綁定帳號(開 App、回前景、立即同步):**只推不拉**,比對 `setting/0` 的
  `*UpdatedAt` 與本機 `*ModifiedAt`,本機較新的領域整份覆寫雲端。
- 登入尚未綁定的帳號:逐領域判斷推 / 拉,兩邊都有資料時跳對話框
  (`showSyncConflictDialog`)讓使用者選「使用雲端 / 保留本機」。
- 整份快照、last-write-wins、不合併,也沒有刪除紀錄。

改為:**所有同步時機一律先 pull、把雲端資料 merge 進本機,再 push 合併結果**。
多台裝置同帳號的資料最後收斂成同一份,登入不再跳衝突對話框。

> 這推翻 plan 31「多裝置同帳號:不支援合併,沿用 last-write-wins」的決策。

## 已確定的決策

| 項目 | 決策 |
|---|---|
| 觸發時機 | 開 App、回前景、帳戶頁「立即同步」、登入(含尚未綁定的帳號),全部走同一條 pull → merge → push |
| 登入衝突對話框 | 移除。登入一律 merge,不詢問 |
| 刪除 | 加刪除紀錄(tombstone),merge 時尊重刪除,避免被另一端的舊資料帶回來 |
| 播放清單識別 | 以 id 比對。我的最愛固定 `id = 1`、最近播放固定 `id = 2`,自建清單從 `3` 起依序編號 |

## 共通流程

```
_sync(uid)
  ├─ 前置檢查:Firebase 可用、已登入、曲庫就緒、雲端 schemaVersion 不比本機新
  ├─ 讀 setting/0(四個領域的 *UpdatedAt)
  ├─ 逐領域:
  │    remoteChanged = remote *UpdatedAt != 本機記錄的 lastPulled*At
  │    localChanged  = 本機 *ModifiedAt  >  本機記錄的 lastSynced*At
  │    ├─ 兩者皆否 → 跳過
  │    ├─ remoteChanged → 讀子集合,merge 進本機(不 mark*Modified)
  │    └─ merge 後本機與雲端不同,或 localChanged → push,寫回 *UpdatedAt
  └─ 記錄 lastPulled*At / lastSynced*At,更新「上次同步時間」
```

- `remoteChanged` 為否時不讀子集合,開 App / 回前景的成本只有一次 `setting/0` 讀取。
- 同一時間只跑一次 `_sync`(以 Future 鎖住,重入時等待同一個 Future)。
- merge 對每個領域都是**可交換、冪等**的(同一份資料 merge 兩次結果不變),
  兩台裝置同時同步時,下一輪同步會自然收斂。
- `BackupStateStore` 新增每領域的 `lastPulled*At`(雲端 `*UpdatedAt` 的值)與
  `lastSynced*At`(本機時間)。

### 登入

- `prepareSignInSync` / `applySignInSync` / `SignInSyncPlan` 移除,登入成功後直接
  `_sync(uid)` 並綁定 `boundUid`。
- 登入頁的 loading 仍等 `_sync` 完成,讓使用者進到已登入畫面時資料已合併。
- 手機 OTP 自動驗證(`onAutoVerified`)同樣呼叫 `_sync`。
- 換帳號登入(`boundUid` 與目前 uid 不同):本機資料(上一個帳號的)會 merge
  進新帳號。**這是不跳對話框的代價**,需確認可以接受(見「待確認」)。
- 未綁定時不再阻擋上傳(原本 `_upload` 檢查 `boundUid != uid` 就跳過,是為了等對話框)。

## 各領域的 merge 規則

### 設定(`setting/0`)

單一文件,不做欄位級合併:整份 last-write-wins。

- 雲端 `settingUpdatedAt` 比本機 `settingModifiedAt` 新 → 雲端覆寫本機。
- 本機較新 → push。
- 沒有刪除,不需要 tombstone。

### 播放清單(`playlist/{id}`)

#### id 規則

- 我的最愛 `id = 1`、最近播放 `id = 2`(`ensureDefault*` 建立時指定)。
- 自建清單 `id` 從 `3` 起,取「目前最大 id(含 tombstone)+ 1」,避免重用已刪除清單的 id。
- **本機遷移**(一次性,prefs flag):系統清單改成 1 / 2,自建清單依 `createdAt`
  重新編號為 3、4…。遷移後第一次 push 以**整份覆寫**雲端(刪除雲端舊 id 的文件),
  之後才改為 merge 語意。
- 兩台裝置各自新建清單、拿到同一個 id 時,會被當成同一張清單合併
  (名稱取較新的、曲目取聯集)。這是以 id 比對的已知取捨。

#### Schema(`PlaylistEntity` 新增欄位)

```dart
late DateTime updatedAt;        // 名稱、曲目、順序任一變動時更新
DateTime? deletedAt;            // tombstone:刪除清單時設定,不真的刪除這筆
List<RemovedTrack> removedTracks = []; // 成員層級的刪除紀錄 {trackId, removedAt}
DateTime? recentlyClearedAt;    // 最近播放「清空」的時間
```

- 刪除清單改為設 `deletedAt`(並清空 `trackIds`),UI 查詢一律過濾 `deletedAt == null`。
- `removeTrack` 時在 `removedTracks` 記 `{trackId, removedAt: now}`;`addTrack`
  重新加入時移除該筆刪除紀錄。

#### 合併(同 id 的本機 L 與雲端 R)

1. 只有一邊有 → 直接採用。
2. `deletedAt`:任一邊有 tombstone,且 tombstone 比另一邊的 `updatedAt` 新 → 結果為 tombstone。
   否則(另一邊在刪除後又改過)保留清單。
3. 名稱:取 `updatedAt` 較新那邊。
4. 曲目:以 `updatedAt` 較新那邊的順序為基底,再依序接上另一邊多出的曲目;
   接著移除「刪除紀錄的 `removedAt` 比該曲所在那一邊的 `updatedAt` 新」的曲目。
   兩邊的 `removedTracks` 取聯集(同 trackId 取較新的時間)。
5. 最近播放:兩邊依 trackId 聯集、`playedAt` 取較大值,降冪排序、截到 200 筆;
   `recentlyClearedAt` 取較新的,並丟掉 `playedAt` 早於它的紀錄。

### 歌詞(`backupLyrics/{trackDocKey(trackId)}`)

#### Schema(`LyricsEntity` 新增欄位)

```dart
late DateTime updatedAt; // 內容變動時更新(目前雲端用 addedAt 充當)
DateTime? deletedAt;     // tombstone:刪除歌詞時設定,content 清空
```

- `deleteByTrackId` 改為設 `deletedAt`、清空 `content`;`getAllSync`、`findByTrackId`
  等讀取端過濾 tombstone。AI 產生任務的空內容佔位(`content == ''`、`deletedAt == null`)
  仍不算歌詞,也不上傳。
- 雲端文件加 `deletedAt` 欄位;tombstone 文件不帶 `content`。

#### 合併(同 trackId)

- `updatedAt` / `deletedAt` 中時間較新的那個事件勝出(內容或刪除)。
- 只有一邊有 → 直接採用。

### 統計(`monthlyStats/{yyyy-MM}`)

- 逐日明細以 `(day, trackId)` 為鍵合併,`playCount` / `listenMs` **取較大值**(不相加:
  雲端那份本來就包含這台裝置先前推上去的數字,相加會重複計算)。
  - 已知取捨:兩台裝置同一天播放同一首,只會記到較多的那一台的次數。
- 月加總(`PeriodStatEntity`)同樣逐月取較大值。
- 「重設統計」:本機與 `setting/0` 記 `statsResetAt`;merge 時兩邊取較新的
  `statsResetAt`,丟掉該時間點(含當日)以前的明細與月加總。
  `uploadAfterReset` 改走 `_sync`。

## 雲端格式

- 不再「先刪掉本機沒有的雲端文件」:刪除改由 tombstone 表示。
- push 仍是整批寫入本機所有項目(含 tombstone);之後可優化為只寫有變動的項目。
- `schemaVersion`:plan 31 的 9 尚未發佈(v1.2.17 為 8),本次變更一起併入 **9**,不另外升版。
- tombstone 保留 **180 天**,之後本機與雲端一併清除。裝置離線超過 180 天再同步,
  刪除過的資料可能被帶回來。

## 「找不到 track」的處理(修訂 plan 31)

plan 31 規定 pull 時找不到 track 的播放清單成員 / 歌詞「不存,下次 push 自然不帶」。
改為 merge 語意後,這樣會讓 push 把雲端的資料刪掉,所以改為:

- **一律保留**,不過濾。播放清單顯示時本來就會以曲庫解析 trackId,對不到的不顯示;
  歌詞只在播放對應曲目時才讀,多存幾筆沒有影響。
- `TrackRepository.availablePathKeys` 若沒有其他使用者,一併刪除。

## Google Drive 備份(目前停用)

不在這次範圍。`LinkChoice`、`cloud_backup_found_dialog`、`drive_link_tile` 仍由
`GoogleDriveBackupService` 使用,不動。`sync_conflict_dialog.dart` 只有 Firestore
登入流程使用,一併刪除(含只有它用到的 l10n 字串)。

## 實作順序

1. `BackupStateStore`:`lastPulled*At` / `lastSynced*At`、`statsResetAt`。
2. Schema:`PlaylistEntity`(`updatedAt`、`deletedAt`、`removedTracks`、`recentlyClearedAt`)、
   `LyricsEntity`(`updatedAt`、`deletedAt`),`build_runner` 產生 `.g.dart`。
3. Repository:刪除改 tombstone、讀取端過濾、寫入時更新 `updatedAt`;播放清單 id 規則。
4. 播放清單 id 本機遷移(1 / 2 / 3…)與遷移後第一次整份覆寫雲端。
5. 各領域 `XxxSync.merge(userDoc)`(純函式的 merge 邏輯獨立出來,方便測試)。
6. `SyncService._sync`:取代 `_maybeUpload` / `_upload` / `prepareSignInSync` /
   `applySignInSync` / `syncAfterSignIn`;開 App、回前景、立即同步、統計重設、登入都改呼叫它。
7. 登入頁:移除對話框與 `SignInSyncPlan`,loading 內 await `_sync`。
8. tombstone 180 天清除。

## 測試涵蓋(實作時補上)

- 播放清單 merge:單邊新增、兩邊各加不同曲目、一邊刪成員另一邊未動、刪除後另一邊又改過、
  刪除清單 tombstone、最近播放聯集 / 清空、id 遷移。
- 歌詞 merge:較新內容勝出、刪除勝出、刪除後另一邊又更新。
- 統計 merge:取較大值、冪等(同一份 merge 兩次結果不變)、重設後丟棄舊資料。
- 設定:較新的一方勝出。
- `_sync`:雲端未變不讀子集合、本機與雲端皆未變不 push、merge 後與雲端不同才 push。

## 待確認

- 換帳號登入時,本機(上一個帳號)的資料會直接 merge 進新帳號,是否可接受?
  另一個選擇是:`boundUid` 變更時先清空本機的播放清單 / 歌詞 / 統計,再 pull 新帳號的資料。
- 統計同一天同一首在兩台裝置播放時取較大值(會少算),是否可接受?
  若要精確相加,雲端需要按裝置分開存(`days.{day}.{trackKey}.{deviceId}`)。
