# 39 - 本機音樂頁記住資料夾與排序(含同步)

## 目標

本機音樂頁(`LocalMusicPlaylistPage`)選的資料夾篩選與排序方式要記下來,
下次開啟時沿用;沒有紀錄時用預設(全部資料夾、加入時間新到舊)。
紀錄需同步到 Firestore。

## 決策(修訂:改為播放清單第 0 筆)

> 初版另開 `user/{uid}/localMusic/0` 集合與獨立同步領域;改為把本機音樂當成
> **播放清單 id 0** 的系統清單,跟其他清單同一套儲存與同步,另開的集合、
> `SyncDomain.localMusic`、`localMusicModifiedAt` 與 SharedPreferences key 一併移除
> (功能尚未發佈,不做 prefs 遷移)。

| 項目 | 決策 |
|---|---|
| 本機儲存 | `PlaylistEntity` id `0`,`isLocalMusic = true`;資料夾存 `folder`,排序存 `sortField` / `sortDescending`(同 plan 40) |
| 建立 | `PlaylistRepository.ensureDefaultLocalMusic`(App 啟動,同我的最愛 / 最近播放),不 markModified |
| 雲端 | `user/{uid}/playlist/0`,跟其他清單同一份推送;多 `isLocalMusic`、`folder` 欄位 |
| Google Drive 備份 | `playlists.json` 一併帶上 |
| 變更 | `setLocalMusicFolder` / `setSort(0, …)` 寫入並 `markPlaylistModified` |
| UI 隔離 | `playlistsProvider` 濾掉 `isLocalMusic`,播放清單列表、加入清單、搜尋都看不到它 |
| 頁面讀取 | `localMusicViewProvider`:watch 清單 0 轉成 `LocalMusicViewState`;沒有這筆時為預設 |

## 規則

- 本機音樂的排序不允許 `custom`,預設 `TrackSort()`(加入時間新到舊);
  一般清單預設 `custom`(清單順序)。
- 合併(`mergePlaylists`):本機音樂與我的最愛 / 最近播放一樣是唯一的系統清單,雲端有就用雲端。
- 「有沒有使用者資料」(登入判斷推 / 拉):本機音樂有資料夾或排序紀錄才算。
- 整份還原(`restoreFromRemote`)後若沒有本機音樂這筆,補建一筆預設的,
  避免之後寫入找不到。寫入時同樣找不到就先建立。
- 紀錄的資料夾在目前曲庫中不存在時,頁面顯示「全部」,但**不清掉紀錄**。

## 相容性

- Isar 新增欄位皆有預設 / nullable,不需遷移;要跑 `build_runner`。
- 舊版 App 讀到 `playlist/0` 會當成一般清單,顯示一個名為「Local Music」的空清單;
  舊版推送時也會保留它。新版發佈前的已知取捨。
- 不改 `schemaVersion`。

## 啟動同步

`SyncService` 建立時跑一次上傳檢查(冷啟動不會觸發 `onResume`,見 `_syncOnLaunch`)。
