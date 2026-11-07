# 38 - trackId(音檔 SHA-256)為曲目身份,移除 pathKey

承 [31](31-track-entity-path-sync.md)、[33](33-pathkey-identity-trackid-legacy.md)。
33 把 pathKey 定為曲目身份,但 **pathKey 尚未發佈**(最新 tag v1.2.17 仍是舊的
sha1 trackId、sync schemaVersion 8)。改為:

- **trackId = 音檔全檔 SHA-256(64 碼 hex)是唯一的曲目身份**:歌詞、統計、播放清單、
  雲端同步、AI 歌詞任務(已送 `trackId`)一律以它關聯。
- **移除 pathKey**;`TrackEntity.path` 保留,作為「實體檔案」的唯一鍵與讀檔路徑。
- 遷移**直接從已發佈的舊資料(sha1 trackId)轉到 SHA-256**,跳過 pathKey;只跑過 33
  的開發機另外處理(見「來源二」)。

## 為什麼

| | pathKey | trackId(SHA-256) |
|---|---|---|
| 換手機 / 重灌還原 | 路徑不同就對不上 | 內容相同就對上 |
| 檔案搬移 / 改名 | 資料斷掉 | 不受影響 |
| Firestore doc id | 需 `trackDocKey` 轉 sha1 | 直接用 |
| 與後端 AI 任務 | 另算 hash | 同一個值 |
| 成本 | 免費 | 需讀全檔(見下方「成本」) |

## 決策

| 項目 | 決策 |
|---|---|
| 身份欄位名稱 | 沿用既有的 `trackId` 欄位(Isar 欄位改名等於新欄位、舊值讀不到;沿用同名欄位,遷移時把 sha1 值就地改寫成 SHA-256) |
| 播放清單 | `trackIds` 重新成為有效清單;`pathKeys` 移除 |
| pathKey | 全部移除(含 `TrackPathKey`、`trackDocKey`)。`TrackEntity.path` 存 MediaStore 原始路徑、為 unique;路徑別名不再正規化,同一檔案從別名開啟時以內容(trackId)比對 |
| trackId 何時算 | **掃描時就算好**:新檔或 size / mtime 變動的檔案讀全檔重算,其餘沿用 TrackEntity 快取。算不出來(讀不到檔案)的不列入曲庫。外部開啟 / 選檔登記時當下算單一檔案 |
| hash 實作 | Android 原生 `MessageDigest.getInstance("SHA-256")`(`FileHashChannel.kt`,背景執行緒池);沒有原生實作時(測試、背景 isolate)退回 Dart isolate + `package:crypto`,結果相同 |
| 進度 UI | 一次要算 ≥ 10 個檔案時由 `TrackEntityMigrationGate` 蓋上「更新音樂庫 / Refresh Music Library」並顯示 `done / total`;版本升級遷移另外顯示「只會執行一次」說明 |
| 封面 | 仍存在 `TrackEntity`,以 trackId 為單位:同 trackId 的所有 entity 一起更新 |
| sync schemaVersion | 維持 9(9 未發佈,格式直接改);Firestore doc id / map key 直接用 trackId |
| 新手機還原 v8(sha1 key)雲端資料 | 不支援(選項 b):v8 的雲端資料只在原手機升級時遷移,遷移後推送新格式 |
| 只跑過 plans/33 的開發機 | 不另外處理:其 pathKey 資料無法對到,視同對不到而丟棄(未發佈) |

## Schema

### `TrackEntity`

```dart
@Index(unique: true)            // 實體檔案唯一鍵
late String path;               // MediaStore `_data` 絕對路徑

@Index(type: IndexType.hash)    // 非 unique:內容相同的多個檔案共用
late String trackId;            // 音檔全檔 SHA-256

late int sizeBytes;
late int modifiedMs;
String? lyricsSha256;           // 不變
// 移除:pathKey、audioSha256(即 trackId)
```

- 寫入改用 `putByPath`;`TrackRepository`:`findByPath` / `findByTrackId`(優先檔案存在的那筆)/
  `findAllByTrackId` / `availableTrackIds` / `setLyricsSha256`。

### 關聯資料

| Entity | 身份欄位 | 移除 |
|---|---|---|
| `LyricsEntity` | `late String trackId`(hash index,寫入端保證一首一筆) | `pathKey` |
| `DailyTrackStatEntity` | composite `(day, trackId)` | `pathKey` |
| `PlaylistEntity` | 有序 `trackIds` | `pathKeys` |
| `RecentlyPlayedEntry` | `trackId` | `pathKey` |
| 歌詞 pending sync store | key 為 trackId | — |

## 本機遷移

新的 flag `track_identity_sha256_done`(與 31 / 33 的 flag 分開)。仍由
`TrackEntityMigrationGate` 擋在 UI 與曲庫載入之前。

1. **掃描曲庫**:`musicLibrarySource.scan()` 算好每個檔案的 trackId 並 upsert
   `TrackEntity`;第一次要讀全部檔案,Gate 顯示「更新音樂庫」進度。掃到 0 首就延後。
2. **建 resolver**:舊 sha1 → `TrackFingerprintEntity.path` → `TrackEntity.trackId`。
   值本身已是本機的 trackId 時原樣回傳。
3. **單一 `writeTxn` 內改寫**:

| 資料 | 對到 | 一對多 | 對不到 |
|---|---|---|---|
| 封面 | 寫進同 trackId 的所有 `TrackEntity` | 取第一個 | 圖檔刪除 |
| 歌詞 | `trackId` 就地改成 SHA-256 | 取第一個;同 trackId 已有就丟棄 | 刪除 |
| 播放清單 `trackIds` | 依原順序對映、去重 | 取第一個 | 移除該項 |
| 最近播放 | 逐筆對映、去重 | 取第一個 | 移除 |
| 每日統計 | `(day, trackId)` 合併次數與時長 | 取第一個 | 保留原值(只用於加總) |

4. 清空 `TrackFingerprintEntity` / `TrackCoverEntity`;pending sync store 重新對映 key;
   標記 playlists / lyrics / stats 已修改,下次同步整份以新格式推送。

## 執行期

- 每次掃描只重算新檔與 size / mtime 變動的檔案,一般掃描幾乎沒有成本。
- 檔案內容變動(重算後 trackId 不同):同一筆 `TrackEntity` 改成新的 trackId,
  舊 trackId 上的歌詞 / 統計 / 播放清單不會自動搬移(之後視需要再做)。
- 播放清單播放:`trackId → path`,多個 path 時取檔案存在的那筆。

## 雲端(Firestore / Google Drive)

- 文件 id、map key 直接用 `trackId`,`trackDocKey` 移除;欄位 `pathKey` 改名 `trackId`。
- v8 雲端 / Drive 備份的 sha1 資料:歌詞與播放清單以 `availableTrackIds` 濾掉,統計保留(只用於加總)。

## 成本(實測 `package:crypto`,Apple M1 AOT)

SHA-256 139 MB/s;推估中階 Android 約 50 MB/s(低階 25–40 MB/s),原生實作快 3–5 倍。

| 情境 | 純 Dart 估計 |
|---|---|
| 一首 MP3 320kbps(~10 MB) | ~0.2 秒 |
| 遷移時只算被引用的 200 首 | ~40 秒(原生 ~10 秒) |
| 背景算完 2000 首 MP3(~16 GB) | ~5–6 分鐘(原生 ~1–2 分鐘) |

## 驗證

- `flutter analyze`。
- 測試:`track_repository_test`(同內容不同 path、findByTrackId 優先存在的檔案、
  setLyricsSha256、內容變動改 trackId)、`content_sha256_test`(Dart 實作)。
- 實機:從 v1.2.17 升級(遷移 + 進度畫面)、全新安裝(第一次掃描顯示進度、
  沒有「只會執行一次」說明)、之後加入少量歌曲(不蓋畫面)、外部開啟曲庫內的歌。
