# 39 - 本機音樂頁記住資料夾與排序(含同步)

## 目標

本機音樂頁(`LocalMusicPlaylistPage`)選的資料夾篩選與排序方式要記下來,
下次開啟時沿用;沒有紀錄時用預設(全部資料夾、加入時間新到舊)。
紀錄需同步到 Firestore,存在**獨立的集合** `localMusic`,與 `playlist` 同層級。

## 決策

| 項目 | 決策 |
|---|---|
| 雲端位置 | `user/{uid}/localMusic/0`(新集合 `localMusic`,單一文件,docId 比照 `setting/0`) |
| 同步領域 | 新增第五個領域 `SyncDomain.localMusic`(`LocalMusicSync`),與設定 / 播放清單 / 統計 / 歌詞同一套調度 |
| 時戳 | 本機 `BackupStateStore.localMusicModifiedAt`;雲端推送後在 `setting/0` 寫 `localMusicUpdatedAt`(與其他領域一致) |
| 同步語意 | 沿用目前 `SyncService`:登入時判斷推 / 拉(兩邊都有時以雲端為主);之後回前景 / 立即同步只推本機較新者 |
| 本機儲存 | 獨立的 `LocalMusicViewController`(SharedPreferences),不併進個人化設定 |
| 頁面讀取 | 頁面 watch controller,不另存一份本地 state;登入拉回雲端狀態後頁面即時套用 |
| Google Drive 備份 | 目前停用,不加 |

## 文件格式(`localMusic/0`)

| 欄位 | 型別 | 說明 |
|---|---|---|
| `folder` | string / null | 資料夾路徑;null 為全部 |
| `sortField` | string | `TrackSortField.name` |
| `sortDescending` | bool | 排序方向 |
| `updatedAt` | timestamp | 伺服器時間,僅供觀察 |

- 排序欄位未知或為 `custom`(本頁不提供)時視為沒有紀錄,回預設排序;方向缺值用預設方向。

## 資料夾路徑不存在

- 紀錄的資料夾在目前曲庫中不存在(重新掃描後被刪、或另一台裝置的路徑不同)時,
  頁面顯示「全部」,但**不清掉紀錄**,資料夾之後再出現時仍會套用。

## 相容性

- 舊版 App 不認得 `localMusic` 集合與 `localMusicUpdatedAt`,不會讀也不會刪,沒影響。
- 不改 `schemaVersion`:只是新增集合,舊資料格式不變。
- Firestore rules 對 `user/{uid}/**` 只限本人讀寫,不需改後端。
