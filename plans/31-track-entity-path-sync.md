# 31 - TrackEntity 與以 pathKey 為準的曲目識別

## 背景與目標

目前 trackId 是內容指紋(`sha1(size + 頭尾 64KB)`,見 `TrackFingerprintService`),
用於本機關聯(歌詞 / 封面 / 統計 / 播放清單)與雲端同步。改為:

- 新增 Isar `TrackEntity`,一個實體檔案一筆,以正規化路徑 **`pathKey`** 為唯一鍵。
- **trackId 一律改用 `pathKey`**:本機關聯、雲端、備份全部存 pathKey,不再有 sha1。
  `TrackEntity.id`(autoIncrement)只是 Isar 主鍵,不對外使用、不存進任何關聯欄位。
- `TrackFingerprintEntity`、`TrackCoverEntity` 標為 deprecated;`TrackMetadataEntity`(只有 iOS 用)已刪除。

## 範圍:只做 Android

iOS 尚未上架,**Dart 端的 iOS 程式碼已全部移除**(`ios/` 平台目錄與 pubspec 的
iOS icon 設定保留):`DocumentsMusicSource`、`TrackMetadataService` /
`TrackMetadataEntity`、iOS 匯入音樂、各處 `Platform.isIOS` 分支、Apple App Check、
`firebase_options.dart` 的 iOS 設定、歌詞任務的非 Android inline 執行路徑,以及
只有 iOS 用到的 5 個 l10n 字串。上架 iOS 時再一起實作(含路徑正規化:相對 Documents
路徑、NFC、`/private/var` 別名、APFS 區分大小寫),Firebase iOS 設定可從 git 歷史取回。

## 已確定的決策

| 項目 | 決策 |
|---|---|
| 比對鍵 | 只用 pathKey(同一實體檔案一筆)。不用 deviceId、不做 size / hash 驗證 |
| 找不到 track | 下載同步時,pathKey 對不到「本機存在的檔案」→ 該筆不存;下次 push 自然不帶(等同雲端刪除) |
| 同 path 不同檔 | 不區分,pathKey 相同即視為同一首 |
| 曲庫未就緒 | 沒權限 / 尚未掃完 / 掃到 0 首 → 跳過整次同步(本機沒資料,備份無意義) |
| 統計 | 只用來記使用量,對不上的 track 也保留 |
| 外部開啟的檔案 | 建立 `TrackEntity`,和曲庫曲目一樣參與 push |
| 掃描造成的 UI 重建 | 由 UI 層處理(掃描完成後一次更新列表、列表項目只監聽自己的資料) |
| 換手機 / 重灌 | 機率小,不特別處理 |
| 多裝置同帳號 | 不支援合併,沿用現有 last-write-wins |

## Schema

### 新增 `TrackEntity`(`lib/features/music_list/models/track_entity.dart`)

```dart
@collection
class TrackEntity {
  Id id = Isar.autoIncrement; // 僅 Isar 主鍵,不對外使用

  late String path;          // 實際讀檔用的路徑(MediaStore `_data` 絕對路徑)

  @Index(unique: true, replace: false)
  late String pathKey;       // 同一實體檔案的唯一鍵 = trackId,見「一檔一筆:pathKey」

  late int sizeBytes;        // metadata 快取失效判斷(取代 TrackMetadataEntity)
  late int modifiedMs;

  String? title;
  String? artist;
  String? album;
  int? albumId;              // Android MediaStore 專輯 id(內嵌封面用)
  int? durationMs;

  String? coverImagePath;    // 自訂封面(取代 TrackCoverEntity)
  int? coverColorValue;

  late DateTime addedAt;     // 第一次建立時設定,之後不再改變
  late DateTime updatedAt;   // 任一欄位變動時更新
}
```

- 同一實體檔案只有一筆(`pathKey` unique index 保證)。upsert **一律用產生的 `putByPathKey`**
  (Isar `putByIndex`:同 index key 已存在時更新該筆、保留原 id)。
- 不加 `replace: true`:加了之後一般 `put()` 會刪舊筆、配新 id;不加則誤用時直接報錯。
- `putByIndex` 是**整筆覆寫**:更新時先 `getByPathKey` 讀出舊的那筆、在上面改欄位再寫回,
  否則 `addedAt`、封面等沒帶到的欄位會被蓋掉(`late` 欄位沒賦值則直接報錯)。

### trackId 改為 pathKey(型別維持 String)

- `Track.id`、`LyricsEntity.trackId`、`DailyTrackStatEntity.trackId`、
  `PlaylistEntity.trackIds`、`RecentlyPlayedEntry.trackId`、背景歌詞 isolate protocol
  的值一律改存 pathKey。
- 型別都是 String,**欄位定義不用改**,改的是「值的來源」與相依的查詢邏輯,
  churn 比改 int 小很多。欄位名稱**確定維持 `trackId`,不改名、不另加欄位**(改名會動到約 80 個檔案),
  以文件註明 trackId 即 pathKey。
- `DailyTrackStatEntity` 的複合 index(`day` + `trackId`)不用改,`title` 保留。

### Deprecated(保留 schema,不刪)

| Entity | 取代者 | 保留原因 |
|---|---|---|
| `TrackFingerprintEntity` | 無(指紋機制移除) | 遷移需要它的 path ↔ hash 對照,把舊 sha1 trackId 轉成 pathKey |
| `TrackCoverEntity` | `TrackEntity.coverImagePath` / `coverColorValue` | 遷移時帶入封面 |

- class 標 `@Deprecated`,只允許遷移程式碼使用。
- **schema 長期留在 `openIsar()` 的清單裡**:Isar 開啟時若 collection 不在 schema 清單,
  可能直接刪除資料(實作前先實測確認)。使用者跳版升級(vN-1 → vN+1)時仍需要舊資料遷移,
  所以不能在下一版就移除。遷移成功後對三個 collection `clear()`,空 collection 幾乎沒有成本。
- `TrackFingerprintService`、`lib/core/storage/track_id_cleanup.dart`(會把非 40 碼 hex
  的 trackId 全清掉,與 pathKey 衝突)直接刪除,連同 `main.dart` 的呼叫。

## 一檔一筆:pathKey

同一個實體檔案可能以不同字串出現(路徑別名、大小寫),unique index
只比字串,所以另存一個正規化後的 `pathKey` 當唯一鍵;`path` 保留實際路徑供讀檔。

### `TrackPathKey.of(String rawPath)`(`lib/features/music_list/services/track_path_key.dart`)

依序(Android):

1. **解析別名**
   - 檔案存在 → `File(raw).resolveSymbolicLinksSync()` 取真實路徑
     (`/sdcard`、`/storage/self/primary` → `/storage/emulated/0`)。
   - 檔案不存在 → 退回前綴對照表:
     `/sdcard/`、`/mnt/sdcard/`、`/storage/self/primary/` → `/storage/emulated/0/`。
2. **格式整理**:`package:path` 的 `p.normalize`(合併 `//`、處理 `.` / `..`、去尾端 `/`)。
3. **大小寫**:轉小寫(共享儲存 FUSE 與 SD 卡 FAT/exFAT 皆不分大小寫)。

Unicode NFC 正規化主要是 iOS 的問題(檔案系統可能回傳 NFD),Android 同一個檔案
的路徑位元組固定,這次不做,也就不需要新增 `unorm_dart` 依賴。

### 使用規則

- **所有路徑進入點都要先過 `TrackPathKey.of`**,不得直接拿原始字串比對或寫入:
  曲庫掃描、外部開啟音檔(`external_file_open_service.dart`,目前以 `filePath ==` 比對)、
  `TrackFileMatcher`、版本遷移。
- 掃描時若兩筆來源算出同一個 `pathKey`(例如 MediaStore 偶發的重複列),只保留一筆。

### 範圍外

- **內容相同的兩個不同檔案**(複製出來的檔案)仍是兩筆。
- bind mount 等非 symlink 的別名(例如 `/mnt/media_rw/XXXX` 與 `/storage/XXXX`)不處理;
  MediaStore 一律回 `/storage/...`,實務上不會遇到。

## 曲庫掃描(`MediaStoreMusicSource`)

1. 列舉音檔路徑 → 以 `TrackPathKey.of` 算出 pathKey。
2. 在**一個 `writeTxn`** 裡對每個 pathKey upsert `TrackEntity`:
   - 不存在 → 新建,`addedAt` 與 `updatedAt` 設為當下時間。
   - 存在且 size / mtime 未變 → 沿用,不重讀 metadata。
   - 存在但 size / mtime 變了 → 更新 metadata 與 `updatedAt`,`addedAt` 不變。
3. 本次沒掃到的 `TrackEntity`:**不刪除**,僅不出現在曲庫列表。
   SD 卡暫時卸載、權限被收等情況檔案只是暫時消失,刪掉會連帶失去歌詞 / 封面 / 播放清單成員。
4. `Track` 由 `TrackEntity` 組出,`Track.id = entity.pathKey`。
5. 對外提供「曲庫已就緒」狀態(有權限、完整掃描完成、曲目數 > 0),供同步判斷。

### UI 更新

- 曲庫列表在**掃描完成後一次**更新,不在掃描過程中逐筆觸發。
- 列表項目(封面、標題等)只監聽自己那筆 `TrackEntity`(`watchObject` / 依 pathKey 的
  provider family),某一首歌變動只重建那一列,不重建整個列表。

## 外部開啟的檔案(`external_file_open_service.dart`)

- 有實體 `filePath` → 算 pathKey,`putByPathKey` 建立 / 更新 `TrackEntity`,
  與曲庫曲目同等對待(可加歌詞、封面、統計,下次 push 一起上雲端)。
- 只有 content URI、還原不出 `filePath` → 算不出 pathKey,維持現在的臨時 Track
  (不建 `TrackEntity`、不能存歌詞與封面)。
- 這類 entity 不在曲庫掃描結果裡,不出現在曲庫列表;是否在播放清單中可播放,
  以檔案是否存在為準(見下方「找得到 track」的定義)。

## 雲端同步(Firestore)

`SyncService.schemaVersion` 8 → 9。

### 「找得到 track」的定義

`TrackEntity` 有這個 pathKey,**且** `File(entity.path)` 目前存在。
只有 entity 但檔案已被刪除,視為找不到。

### push 前檢查

曲庫未就緒 → 整次同步跳過(push 與 restore 都不做)。

### 各領域格式

本機關聯欄位已是 pathKey,push / restore **不需要轉換**,直接寫出 / 讀回。

| 領域 | 現在 | 改為 |
|---|---|---|
| `playlist/{playlistId}` | `trackIds: [sha1]`、`recentlyPlayed[].trackId` | 同欄位名,值改為 pathKey |
| `backupLyrics/{docId}` | doc id = sha1 | doc id = `sha1(pathKey)`(pathKey 含 `/` 不能當 doc id),欄位加 `trackId`(= pathKey) |
| `monthlyStats/{month}` | `days.{day}.{trackId}` | `days.{day}.{sha1(pathKey)}`(map key 不能含 `.` 等字元),值加 `trackId`(= pathKey) |

- restore:
  - 播放清單 / 歌詞:找不到 track → **不存**。
  - 統計:找不到也保留(只用於加總使用量)。

## 歌詞後端任務改用 jobId

### 現況

client 把 `trackId` 傳給 `generate_lyrics` / align callable,後端把任務狀態寫到
`user/{uid}/lyrics/{trackId}`,`LyricsPendingSyncService` 以 trackId 為 doc id 監聽。
pathKey 含 `/` 不能當 doc id,且每次任務共用同一個 doc 也無法區分新舊任務。

### 改為

- 送出任務前,client 以 `collection('lyrics').doc().id` 產生新的 **jobId**
  (Firestore 在本機產生,不需網路)。
- callable 參數加 `jobId`,後端改以 `user/{uid}/lyrics/{jobId}` 為任務文件;
  `trackId`(pathKey)與 `title` 一併寫進文件欄位。
- Storage 路徑改為 `generate/{uid}/{jobId}.m4a`(pathKey 不適合當檔名)。
- `LyricsPendingSyncStore` 改以 jobId 為 key,值帶 `trackId`(pathKey)、`mode`、`title`;
  監聽 `lyrics/{jobId}`,終態時把結果寫回該 pathKey 的 `LyricsEntity`。
- `LyricsEntity` 新增 `String? jobId`:記錄這首歌最近一次送出的任務,
  供 UI 顯示進度、重開 app 後接續追蹤。

### 「產生」模式:先建空內容的 `LyricsEntity`

- 送出任務時,這首歌還沒有歌詞 → 建一筆 `content = ''`、`source = generated`、帶 `jobId`
  的 `LyricsEntity`;已有歌詞(對時模式)→ 只更新 `jobId`,內容不動。
- **「有沒有歌詞」一律以 `content` 是否為空判斷**,不以 entity 是否存在判斷。
  UI 大多已經是用解析後的歌詞 `isNotEmpty` 判斷(`player_artwork_panel`、`lyrics_action_tiles`、
  `lyrics_mode_menu`、`lyrics_view`、`lyrics_editor_page`),不用改。
  需要補上「略過空內容」的地方:
  - 雲端 push(`lyrics_sync.dart`)與 `hasLocalData()`
  - Google Drive 備份(`lyrics_backup.dart`)
  - 歌詞匯出(`lyrics_export_service.dart`)
  - 其他直接用 `findByTrackId(...) != null` 或 `getAllSync()` 數量判斷的地方(實作時 grep 確認)
- 任務終態:
  - 成功 → 寫入 `content`、清掉 `jobId`。
  - 失敗 → `content` 為空就刪掉這筆 entity;有內容(對時失敗)就只清掉 `jobId`。

### 跨 repo 的變更

jobId 由**前端產生、傳給後端**;後端拿到後直接當任務文件的 doc id。

- 後端 Cloud Functions(`firebase.json` 的 `functions` 目錄,不在這個 repo)要改成讀
  callable 參數裡的 `jobId`,以 `user/{uid}/lyrics/{jobId}` 寫任務狀態(現在是用參數裡的
  `trackId` 當 doc id)。過渡期用 `jobId ?? trackId`,讓舊版 client 繼續可用。
- `firestore.rules` 的 `match /lyrics/{trackId}` 改名為 `{jobId}`(規則內容不變)。
- 升級當下進行中的任務(doc id 是 sha1):遷移時保留舊 key 繼續監聽到終態,
  只把結果寫回時的 trackId 轉成 pathKey。

## Google Drive 備份(目前停用)

`playlists_backup.dart`、`lyrics_backup.dart`、`statistics_backup.dart` 的 JSON 格式
不用改欄位,值隨本機一起變成 pathKey。

## 版本更新的本機資料遷移

升級後第一次啟動、曲庫掃描完成後執行一次(prefs flag `track_entity_migration_v1_done`):

1. 用 deprecated 的 `TrackFingerprintEntity`(path ↔ hash)建立 `sha1 → [pathKey]` 對照;
   對每個掃到的檔案已由掃描建立 `TrackEntity`(`addedAt` 為建立當下時間)。
   - 舊 fallback id(Android MediaStore 數字 id)也納入對照
     (透過 `pathForFallbackId` 的現有邏輯)。
2. `TrackCoverEntity` → 寫入對應 `TrackEntity` 的 `coverImagePath` / `coverColorValue`。
3. `LyricsEntity`、`DailyTrackStatEntity`、`PlaylistEntity.trackIds`、`RecentlyPlayedEntry`、
   `lyrics.pendingSyncJobs` 的 sha1 trackId 依對照改寫成 pathKey。
   - 一個 sha1 對到多個 pathKey(同內容多份檔案):歌詞 / 封面複製到每一個;播放清單取第一個。
   - 對不到:歌詞 / 封面 / 播放清單成員丟棄;統計保留原值。
   - 丟棄筆數以 log / crash report 記錄,上線後評估影響範圍。
4. 標記播放清單 / 歌詞 / 統計三個領域為已修改(`BackupStateStore.mark*Modified`),
   讓下一次同步以新格式整份 push,覆蓋雲端舊格式資料。
5. 三個 deprecated collection `clear()`(schema 保留),寫入 flag。

遷移只能在曲庫掃描完成後執行;掃描未就緒時延後到下次啟動,期間同步一律跳過。

### 雲端舊格式資料

restore 遇到 schema 8 的舊格式(trackId 是 sha1)→ 對不到任何 pathKey,不存。
已升級的裝置在第 4 步會 push 新格式覆蓋,實務上只影響「舊雲端資料 + 新裝置登入」,
屬於不處理的換手機情境。

## 其他受影響的功能

- `TrackAudioResolver`:改為 pathKey → `TrackEntity.path` 直接查,刪掉 hash 反查與重算。
- `TrackFileMatcher`(工具頁「從檔案選擇」):`file_picker` 在 Android 回傳的 `path` 是
  複製到 app 暫存目錄的副本(`/data/user/0/<pkg>/cache/file_picker/...`),和曲庫的路徑
  永遠對不上,原本才靠指紋比對。改為:
  1. 取 `PlatformFile.identifier`(原始檔案的 content URI)。
  2. 交給 native 還原實體路徑:重用 `ExternalOpenChannel.kt` 現有的 `resolvePath(uri)`
     (`audio:<id>` / `raw:` / `msf:` / `_data` / DISPLAY_NAME + SIZE 反查),
     在 channel 上新增 `resolvePath` method 對 Dart 開放。
  3. 算 pathKey → 在曲庫的 tracks 中找到 → 直接用。
  4. 有實體路徑但不在曲庫 → 建立新的 `TrackEntity`(與外部開啟相同處理)。
  5. 還原不出實體路徑 → 才走匯入流程(`importFile`,複製進 MediaStore)後重掃比對。
- `MusicLibrarySource.pathForFallbackId`、`audioFilePaths` 中只為指紋服務存在的部分一併刪除
  (遷移用到的部分移到遷移程式碼內)。
- 封面:`cover_import_service` 改寫 `TrackEntity`;`covers/` 裡沒有任何 `TrackEntity`
  引用的圖片檔,在遷移完成後清一次。
- 內嵌封面快取(`embedded_artwork_cache.dart`)以 `sha1(trackId)` 當檔名,值變成 pathKey 後
  舊快取失效、重新抽取,舊檔留在暫存目錄由系統清除。
- `app_data_reset_service.dart`:清除對象加入 `TrackEntity`。

## 實作順序

1. `TrackPathKey` + `TrackEntity` + 掃描 upsert + 曲庫就緒狀態(`build_runner` 產生 `.g.dart`)。
2. `Track.id` 改為 pathKey,封面 / metadata 讀寫改走 `TrackEntity`,舊 entity 標 deprecated。
3. 外部開啟改建 `TrackEntity`。
4. 雲端同步 / 備份:「找得到 track」判斷 + 就緒檢查,`schemaVersion` → 9。
5. 歌詞任務改 jobId(先確認後端可以同步上線)。
6. 本機資料遷移,刪除 `track_id_cleanup.dart` 與 `TrackFingerprintService`。
7. `TrackAudioResolver`、`TrackFileMatcher`、reset 服務、封面孤兒檔清理。
8. UI:曲庫列表掃描完一次更新、列表項目個別監聽。

## 測試涵蓋(實作時補上)

- `TrackPathKey`:Android 別名(`/sdcard` 等)、大小寫、`p.normalize`。
- 掃描 upsert:同 pathKey 重掃 id 與 `addedAt` 不變;size / mtime 變動只更新 metadata;
  消失的 path 不刪;同一次掃描重複 pathKey 只留一筆。
- 同步 restore:找得到 / entity 在但檔案不在 / 沒有 entity;統計一律保留。
- 遷移:sha1 一對多、fallback id、對不到的各領域處理、進行中的歌詞任務。
- 歌詞任務:jobId 監聽到終態後寫回正確 pathKey。

## 實作紀錄(與上文的差異)

- **iOS**:見上方「範圍:只做 Android」,Dart 端 iOS 程式碼已移除;`TrackMetadataEntity`
  一併刪除(只有 iOS 寫入過,Android 上是空的)。標 `@Deprecated` 的只剩
  `TrackCoverEntity`、`TrackFingerprintEntity`。
- **歌詞任務**:
  - `LyricsPendingSyncStore` 仍以 trackId(pathKey)為 key,值多帶 `jobId`;
    UI 端(進行中狀態、階段、取消)都以 trackId 查,不用改。舊紀錄沒有 jobId 時
    以 key(舊 sha1,即當時的任務文件 id)當 jobId。
  - callable 參數 `trackId` 直接帶 jobId、另帶 `jobId`:後端現在以 `trackId`
    參數當任務文件 id,**不改後端也能運作**;之後後端可改讀 `jobId`。
  - Storage 路徑改為 `generate|align/{uid}/{jobId}.m4a`。
  - 取捨:每次送出都是新的任務文件,後端「同一首歌命中既有快照」的快取不再生效,
    重送同一首會重新處理。
- **封面一對多**:同內容多份檔案時封面只給第一個 pathKey(圖檔只有一份,
  共用的話移除其中一首會刪掉別首的圖);對不到曲目的封面圖檔遷移時一併刪除。
- **遷移時機**:一進 app 由 `TrackEntityMigrationGate`(`MaterialApp.builder` 內)判斷:
  flag 已寫 → 略過;本機沒有任何舊資料(新安裝)→ 直接寫 flag;否則蓋上全螢幕 loading,
  遷移自己先掃描曲庫建立 `TrackEntity`,再以 `TrackFingerprintEntity` 的 path 算 pathKey
  對回封面 / 歌詞 / 播放清單 / 統計 / 待同步歌詞任務,結束才移除 loading。沒有音訊權限、
  掃到 0 首或失敗 → 不寫 flag、不擋畫面;`MusicLibrary._scan` 每次掃描前都會
  `await runIfNeeded()`(共用同一次執行),之後授權時從這裡補跑。`SyncService` 的曲庫
  就緒檢查會等 `musicLibraryProvider.future`,因此同步一定在遷移之後。
- **命名**:遷移程式碼內舊關聯鍵一律稱 legacy id、新的稱 pathKey,不用 trackId
  (entity 欄位確定維持 `trackId`,見上方 Schema 一節)。
- **封面孤兒檔**:遷移最後清掉 `covers/` 內沒有任何 `TrackEntity.coverImagePath` 引用的圖檔。
- **UI 更新**:`MusicLibrary` 本來就只在整次掃描完成後更新一次狀態;封面 / 歌詞
  provider 本來就是依 trackId 的 family,不需額外調整。
- **原生**:`ExternalOpenChannel.kt` 新增 `resolvePath` method,Dart 端以
  `ContentPathResolver` 呼叫。
