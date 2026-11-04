# 33 - pathKey 為曲目身份,trackId 改為保留舊值

承 [31](31-track-entity-path-sync.md)。31 的做法是「trackId 欄位不改名,值改存 pathKey」,
同一個名稱在舊資料是 sha1 指紋、在新資料是 pathKey,容易混淆。改為:

- **pathKey 是唯一的曲目身份**:本機關聯、查詢、雲端同步一律以 pathKey 為準。
- **trackId 只保留舊值**(升級前的 sha1 指紋 / MediaStore fallback id),之後新寫入的
  資料 trackId 為 null,不再計算 fingerprint。trackId 不作為任何比對 / 同步依據,
  只是隨資料保存、隨雲端備份附帶。

## 已確定的決策

| 項目 | 決策 |
|---|---|
| trackId 的值 | 只保留升級前的舊值;新資料為 null,不另外算 fingerprint(歌詞任務送出時照舊即時算 `audioFingerprint`,只傳給後端,不寫進 entity) |
| 有 trackId 的 entity | 新增 `pathKey` 欄位,trackId 改為 `String?` 並移除其索引 |
| 播放清單 | 新增有序的 `pathKeys`;舊 `trackIds` 凍結(只留遷移前的值,不再寫入);`RecentlyPlayedEntry` 新增 `pathKey`,`trackId` 改 `String?` |
| 程式碼命名 | 所有實際存 pathKey 的變數 / 參數 / 方法一律改名:`Track.id` → `Track.pathKey`、`trackId` → `pathKey`、`trackIds` → `pathKeys`、`*TrackId*` → `*PathKey*` |
| 雲端 | 上傳時附帶 trackId(有值才帶),比對 / 還原只看 pathKey |
| sync schemaVersion | 維持 9(9 尚未發布,格式直接改) |

## Schema

### 新欄位不加 unique index

Isar 讀到舊資料缺少的非 nullable 字串欄位會回 `''`(`readString` = `readStringOrNull ?? ''`)。
若新的 `pathKey` 加 unique index,開 DB 時對既有資料重建索引會遇到大量相同的空值,
有開啟失敗的風險。因此新欄位只加**一般索引**,唯一性由寫入端(repository / service)
在 transaction 內「先以 pathKey 查既有那筆、沿用其 id 再 put」保證。

### `LyricsEntity`

```dart
@Index(type: IndexType.hash)
late String pathKey;   // 曲目身份
String? trackId;       // 舊值,無索引
```

- 移除 trackId 的 `unique + replace` 索引(新資料 trackId 為 null,保留會互相覆蓋)。
- `LyricsRepository`:`findByPathKey` / `deleteByPathKey`,寫入一律沿用既有那筆的 id。

### `DailyTrackStatEntity`

```dart
@Index(composite: [CompositeIndex('pathKey')])  // 非 unique
late String day;
late String pathKey;
String? trackId;
```

- `StatisticsController` 以 `where().dayPathKeyEqualTo(day, pathKey)` 查當日那筆再更新。

### `PlaylistEntity` / `RecentlyPlayedEntry`

```dart
List<String> pathKeys = [];   // 有序曲目清單(新)
List<String> trackIds = [];   // 凍結:遷移前的舊值
// RecentlyPlayedEntry
late String pathKey;
String? trackId;              // 舊值
```

### 不變

- `TrackEntity`:不新增 trackId(不存 fingerprint)。
- `TrackCoverEntity` / `TrackFingerprintEntity`:維持 deprecated,僅供遷移讀取。

## 本機遷移(改寫 31 的 TrackEntityMigration)

觸發方式不變(一進 app 由 `TrackEntityMigrationGate` 判斷,需要時蓋 loading)。
flag 改為 `track_entity_migration_v2_done`:v1(31 的做法,把 pathKey 寫進 trackId)只在
開發版跑過,換新 flag 讓開發機重跑。resolver 遇到 trackId 本身已是 pathKey 的值原樣回傳,
並把該筆的 trackId 清為 null(它不是舊識別碼)。

舊 trackId **原樣保留**,只補上 pathKey:

| 資料 | 對到 pathKey | 一對多 | 對不到 |
|---|---|---|---|
| 封面 | 寫進 `TrackEntity.coverImagePath` | 只給第一個 | 圖檔刪除 |
| 歌詞 | 補 `pathKey` | 複製到每個 pathKey(trackId 相同) | 刪除 |
| 播放清單 | `pathKeys` 依原順序填入 | 取第一個 | 不放進 `pathKeys`(`trackIds` 仍保留) |
| 最近播放 | 補 `pathKey` | 取第一個 | 移除該筆 |
| 每日統計 | 補 `pathKey`,同日同 pathKey 合併 | 取第一個 | 保留,`pathKey` 暫填舊 trackId(sha1 不以 `/` 開頭,不會對到任何曲目,只用於加總) |
| 待同步歌詞任務 | key 改為 pathKey | 取第一個 | 移除 |

## 雲端同步(schema 9)

| 領域 | 格式 |
|---|---|
| `backupLyrics/{trackDocKey(pathKey)}` | `pathKey`、`trackId?`、`title`、`format`、`source`、`content`、`addedAt` |
| `playlist/{playlistId}` | `pathKeys`、`trackIds`(凍結舊值)、`recentlyPlayed[] { pathKey, trackId?, playedAt }` |
| `monthlyStats/{month}` | `days.{day}.{trackDocKey(pathKey)} { pathKey, trackId?, title, playCount, listenMs }` |

- restore 只看 `pathKey`;沒有 `pathKey` 的文件 / 項目視為舊格式跳過(統計例外:保留,
  pathKey 取 `trackId` 或 map key)。
- Google Drive 備份(停用中)的 JSON 同樣改用 `pathKey` / `pathKeys`,附帶 `trackId`。

## 不能改名的地方(後端契約)

- `generate_lyrics` / align callable 參數 `'trackId': jobId`(後端以它當任務文件 id,
  見 31 實作紀錄)。
- 後端寫進 `user/{uid}/lyrics/{jobId}` 的欄位名稱。

## 實作順序

1. Entity schema(上述四個)+ `build_runner`。
2. `Track.id` → `Track.pathKey`;全專案 `trackId` / `trackIds` / `*TrackId*` 識別字改名
   (排除 entity 的舊值欄位、後端契約字串)。
3. Repository / service 的唯一性處理(歌詞、統計、播放清單)。
4. 雲端同步、Google Drive 備份格式。
5. 改寫 `TrackEntityMigration`。
6. 測試改名與補上新格式。

## 實作紀錄

- 唯一性:`LyricsRepository._put` / `_putAll`(先以 pathKey 查既有那筆、沿用 id)、
  `StatisticsController._record`(`where().dayPathKeyEqualTo`)、`restoreFromRemote`
  寫入前以 `(day, pathKey)` 去重。沒有其他地方直接寫這兩個 collection。
- 改名以腳本對 `trackId` / `trackIds` / `TrackId` / `TrackIds` 全域替換(排除 `.g.dart`、
  兩個 deprecated entity、遷移檔與後端契約那兩行),`Track.id` 依 analyzer 錯誤位置替換。
- 雲端還原的最近播放:沒有 `pathKey` 的項目跳過(原本會變成字串 `'null'`)。
