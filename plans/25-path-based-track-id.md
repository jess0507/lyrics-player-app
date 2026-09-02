# trackId 改為路徑派(取代內容指紋)

狀態:**規劃中**(2026-09-02 起草,未實作)。
影響範圍(預計):`lib/features/music_list/services/`(指紋服務、兩個 source、resolver)、
`lib/features/music_list/models/`、`lib/core/sync/`、`lib/core/storage/`、
`lib/features/player/providers/external_file_open_service.dart`、`lib/features/lyrics/`。
相關:`plans/24-track-info-edit.md`(編輯 tag 會改到檔頭 bytes,是本計畫的直接動機);
`plans/23-ios-support.md`(iOS 沙盒路徑的約定)。

## 決定

trackId 不再是 `sha1(檔案大小 + 頭尾 64KB)`,改為 **`sha1(正規化路徑)`**:

| 平台 | 正規化路徑 | 例 |
| --- | --- | --- |
| Android | MediaStore `_data` 絕對路徑 | `/storage/emulated/0/Music/a.mp3` |
| iOS | 相對於 `Documents/` 的路徑 | `Music/a.mp3` |

仍套一層 sha1 而不直接用路徑字串:id 形狀與現在相同(40 位 hex),
所有消費端(Isar 索引、Firestore doc id 不能含 `/`、雲端函式參數、log)一律不用動。
iOS 必須用相對路徑:App 容器路徑 `/var/mobile/Containers/Data/Application/<UUID>/…`
的 UUID **每次更新 App 都會變**,用絕對路徑會在升版後全部斷鏈。

## 為什麼

- **改 tag 不再改 id**:`plans/24` 的編輯歌曲資訊直接寫檔,內容 hash 會跟著變;
  路徑派讓那份計畫的「id 搬遷」「重建佇列」整段消失。
- **掃描更快**:新檔不再讀 128 KB 算 sha1,也不需要背景 isolate。
- **與多數播放器一致**(MediaStore、foobar2000、MusicBee、Jellyfin 都是路徑派),
  行為好預期。
- **多裝置**:同一路徑才算同一首;另一台沒有那個檔本來就不顯示,雲端歌詞 / 統計
  對不上就是不顯示,接受(2026-09-02 決定)。

## 代價(要明知故犯的部分)

| 情境 | 現在(內容 hash) | 改後(路徑) |
| --- | --- | --- |
| 改檔名 / 搬到別的資料夾 | 播放清單、封面、歌詞、統計都還在 | **全部斷**,變成一首新歌 |
| 在 App 內改 tag(plan 24) | id 變,需搬遷 | 不受影響 |
| 在電腦改 tag 再同步回手機 | id 變,資料斷 | 不受影響 |
| 同一首歌存兩份在不同資料夾 | 同一個 id,共用歌詞 / 封面 | 兩首獨立 |
| 換手機、檔案放在同一路徑 | 同一首 | 同一首 |
| 換手機、路徑不同 | 同一首 | 不同首 |

「搬移 / 改名會斷」是相對現況的倒退。M2 可用「舊路徑消失 + 新路徑出現 + 檔名與大小相同」
的啟發式在掃描時自動接回,成本低、不動 id 設計,先不做。

## 步驟

### M1:切換 id + 一次性搬遷

1. **`TrackIdService`**(`lib/features/music_list/services/track_id_service.dart`,一檔一 provider)
   - `idForPath(String path)`:平台正規化 → sha1。iOS 需注入 Documents 根目錄
     (掃描時已取得,傳入即可,避免每首都 `getApplicationDocumentsDirectory`)。
   - 兩個 `MusicLibrarySource.scan()` 改用它;`Track.id` 不再有 fallback 分支。
2. **`TrackAudioResolver` 簡化**:sha1 單向,反查改為「先查已載入的 `musicLibraryProvider`,
   沒有(背景 isolate / 冷啟動)就 `source.audioFilePaths()` 逐路徑算 id 比對」——
   純字串運算,幾千首也是毫秒級。刪除指紋快取反查與全庫重算兩段。
3. **`external_file_open_service.dart`**:外部開檔目前也算指紋;改為對實際落地路徑算 id
   (若是複製進 cache 的暫存檔,每次開都是新 id,與「不顯示在曲庫」的定位一致;實作時確認)。
4. **一次性搬遷**(`lib/core/storage/track_id_migration.dart`,首次啟動執行一次,
   SharedPreferences 記 `trackIdScheme = 2`)
   - 舊 → 新對照來源:`TrackFingerprintEntity`(path → hash)涵蓋所有算過指紋的檔;
     Android fallback id(MediaStore id)以 `pathForFallbackId` 反查;iOS fallback id 本身就是路徑。
   - 一個 Isar txn 內重寫:`LyricsEntity.trackId`、`TrackCoverEntity.trackId`、
     `PlaylistEntity.trackIds`、`RecentlyPlayedEntry.trackId`、`DailyTrackStatEntity.trackId`
     (composite 索引,需 delete + put)、`lyricsPendingSyncStore` 內的 id。
   - 對不到路徑的舊 id(檔案已不在):原樣保留,不刪;它們本來就不會顯示。
   - 搬遷後 `markLyricsModified / markPlaylistModified / markStatsModified`,
     既有的完整快照推送在下次同步把雲端也改成新 id(`LyricsSync` / `PlaylistsSync` /
     `StatisticsSync` 都是整份覆寫,已確認)。
   - 搬遷需在 `musicLibraryProvider` 第一次掃描之前完成,否則新掃出來的 Track 找不到舊資料。
5. **移除指紋**:刪 `TrackFingerprintService` / `TrackFingerprintEntity`(schema 保留一個版本
   供搬遷讀取,下一版再從 `openIsar` 拿掉並清 collection)。
6. **`plans/24` 同步修訂**:刪除「trackId 會變」整節與 `TrackIdMigrationService`;
   儲存後只需 `musicLibraryProvider.refresh()` 與刷新佇列標題。
7. **驗證**:`flutter analyze`;實機:升版後播放清單 / 封面 / 歌詞 / 統計全部還在;
   登入帳號同步一次後,Firestore 內 doc id 已是新 id;改 tag 後 id 不變;
   改檔名後確認該曲從播放清單消失(預期行為,要在 release note 說明)。

### M2(可選)

- 掃描時偵測「路徑消失 + 同檔名同大小的新路徑出現」自動接回舊 id 的關聯資料。
- 手動「重新連結遺失曲目」入口(播放清單裡顯示為灰色的項目點一下選檔)。

## 邊界 / 風險

- **搬遷跑到一半崩潰**:整個在一個 txn 內,要嘛全成要嘛全不成;flag 在 txn 成功後才寫。
- **Android `_data` 欄位**:Android 10+ 標為 deprecated 但仍填值,`on_audio_query` 已在用;
  若未來某 ROM 回空字串,退回 `content://` URI 字串當正規化路徑。
- **大小寫 / 符號連結**:Android 外部儲存是 case-insensitive FUSE,MediaStore 回傳的路徑
  大小寫固定;不做額外正規化。
- **雲端舊 id 殘留**:另一台尚未升版的裝置推送會把舊 id 又寫回雲端;兩台都升版並各同步一次後收斂。
- **release note 必須提**:改檔名 / 搬移會讓該曲脫離播放清單。
