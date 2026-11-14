# 40 - 播放清單記住排序方式(含同步)

## 目標

播放清單詳細頁(`PlaylistDetailPage`)選的排序方式要**每個清單各自**記下來,
下次開啟該清單時沿用;沒有紀錄時用預設(清單順序)。紀錄隨播放清單同步。

## 決策

| 項目 | 決策 |
|---|---|
| 範圍 | 每個清單各自一份;「最近播放」不提供排序,不記 |
| 本機儲存 | `PlaylistEntity` 新增 `sortField: String?`、`sortDescending: bool?`(null = 沒有紀錄) |
| 雲端 | 跟清單內容同一份文件 `user/{uid}/playlist/{id}`,新增 `sortField` / `sortDescending` 欄位 |
| Google Drive 備份 | `playlists.json` 每筆清單一併帶上(同一套 encode / decode) |
| 變更 | `PlaylistRepository.setSort` 寫入並 `markPlaylistModified`,下次同步推上去 |
| 同步語意 | 沿用播放清單領域:整份推送;登入 merge 時同 id 以雲端為主,排序跟著雲端那份 |
| 頁面讀取 | 詳細頁直接用 `playlistsProvider` 裡該清單的排序,不另存本地 state |

## 還原規則

- `TrackSort.fromStored` 新增 `fallback` / `allowCustom` 參數:播放清單允許 `custom`
  (清單順序),預設也是 `custom`;本機音樂頁維持不允許 `custom`。
- 欄位缺值或未知值 → 預設(清單順序)。

## 相容性

- Isar 新增 nullable 欄位,舊資料讀出為 null(= 預設),不需遷移;要跑 `build_runner`。
- 雲端只新增欄位,舊版 App 推送時會整份覆寫文件(`set` 非 merge)而丟掉這兩個欄位,
  回到預設排序;可接受。
- 不改 `schemaVersion`。
