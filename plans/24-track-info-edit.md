# 編輯歌曲資訊:歌名 / 演出者 / 專輯 / 歌詞直接寫入音訊檔

狀態:**規劃中**(2026-09-02 起草,未實作)。
影響範圍(預計):`lib/features/tag_edit/`(新)、`lib/features/music_list/`、
`lib/features/lyrics/`、`lib/features/player/widgets/`、
`android/app/src/main/kotlin/.../MainActivity.kt`(原生寫檔權限)、`lib/l10n/`。
前置:`plans/25-path-based-track-id.md`(trackId 改路徑派,先做)。
相關:`plans/19-becklog.md` 項目 2「編輯歌詞」、項目 4「曲目中繼資料」;
`plans/8-track-metadata.md`(讀取內嵌歌詞的調查,本計畫是其寫入面)。

## 目標

使用者(尤其是自己做歌的人)能在 App 內改歌名 / 演出者 / 專輯 / 歌詞,
**直接寫進音訊檔的 tag**(ID3v2 / MP4 atom / Vorbis comment),
不存 Isar、不上雲:檔案拿到別的播放器或別台裝置都帶著這些資訊。

## 命名

| 層級 | 命名 | 理由 |
| --- | --- | --- |
| 使用者介面 | 「編輯歌曲資訊」/ en「Edit track info」 | 與既有「曲目資訊」對話框(`music_track_info` = Track info)成對。「Metadata」對一般使用者是術語,且歌詞不算 metadata。 |
| feature 目錄 | `lib/features/tag_edit/` | 橫跨 music_list 與 lyrics 兩個 domain,獨立成 feature。 |
| 頁面 | `TagEditPage`(`tag_edit_page.dart`) | 對應 `PlaylistDetailPage` 等命名。 |
| 寫檔服務 | `TrackTagWriter`(`track_tag_writer.dart`) | 「tag」點明是寫進檔案本身,與 `TrackMetadataService`(ffprobe **讀取**快取)區隔。 |
| 選單項目 | `LyricsMenuAction.editTrackInfo` | 放在歌詞按鈕動作表單,不論歌詞狀態一律顯示。 |
| l10n 前綴 | `tag_edit_*` | 與頁面名一致;演出者 / 檔案位置沿用既有 `track_info_*`。 |

## 可行性調查(2026-09-02)

### iOS:可行,最單純

- 曲目全在 App 沙盒 `Documents/Music/`(匯入時複製進來,`music_import_service.dart`),
  App 是檔案擁有者,`dart:io` 直接覆寫,無任何權限對話框。
- 流程:寫到暫存檔 → `rename` 蓋回原路徑(原子,失敗不會留半個檔)。
- `UIFileSharingEnabled` 已開,使用者從「檔案」App 拿走的就是改好的檔。

### Android:可行,但要走原生寫入權限流程

曲目是掃 MediaStore 來的、不是 App 建立的檔案,scoped storage 下不能用路徑直接寫。
`minSdk = 24`,要分三段處理(全部在 `MainActivity` 的 MethodChannel 加原生方法):

| API | 做法 |
| --- | --- |
| 30+(Android 11+) | `MediaStore.createWriteRequest(resolver, [uri])` → 系統跳「允許修改這個音訊檔?」對話框(每次編輯都會問,無法免除);同意後以 `contentResolver.openFileDescriptor(uri, "rwt")` 把新檔內容寫進去。 |
| 29(Android 10) | manifest 加 `android:requestLegacyExternalStorage="true"`,搭配 `WRITE_EXTERNAL_STORAGE`(`maxSdkVersion="29"`),即可路徑直寫。 |
| 24–28 | `WRITE_EXTERNAL_STORAGE` 執行期權限後路徑直寫。 |

- 寫完必須 `MediaScannerConnection.scanFile(path)`,MediaStore 才會重新解析
  title / artist / album;否則列表要等系統自己重掃。
- SD 卡(secondary storage)在 API < 30 路徑寫入會被擋,退回 SAF
  (`ACTION_OPEN_DOCUMENT` 讓使用者親自選那個檔)——v1 不做,編輯頁以阻擋類警語說明
  (見「警語與唯讀狀態」)。
- `MANAGE_EXTERNAL_STORAGE`(所有檔案存取)可繞過對話框,但 Play 政策只放行檔案管理類
  App,音樂播放器申請會被拒,不採用。

### 寫 tag 的工具:FFmpeg 只能處理一半,MP3 歌詞要自己寫

專案已內建 `ffmpeg_kit_flutter_new 4.3.2`(= FFmpeg 8.0.0)。
`ffmpeg -i in -map 0 -c copy -metadata title=… -metadata artist=… -metadata album=… -metadata lyrics=… out`:

| 容器 | title / artist / album | lyrics |
| --- | --- | --- |
| M4A / MP4(`©lyr`) | ✅ | ✅(`movenc.c` 內建 `"lyrics" → "\251lyr"` 對應) |
| FLAC / OGG(Vorbis comment) | ✅ | ✅(任意 key 原樣寫入 `LYRICS=`) |
| MP3(ID3v2) | ✅ | ❌ **8.0 / 8.1 都不會寫 USLT**;`id3v2enc.c` 到 2026-07-18 才在 master 加入(`id3v2_lang_descr_tags`),尚未進任何 release,ffmpeg_kit 最新 4.6.2(FFmpeg 8.1.2)也沒有。 |

而 MP3 正是曲庫主流。其他選項:
- `audiotags`(Rust lofty):欄位只有 title / artist / album / year / genre / track no / pictures,**沒有 lyrics**。
- `id3_codec`(pure Dart):宣稱可編輯 ID3v2.3 / 2.4,但 README 未提 USLT、
  未說明是否保留既有 frame(APIC 封面),且 3 年未更新。實作時先花半天驗證;
  不合用就**自寫 ID3v2.3 writer**(格式簡單:10 byte header + frames,
  只需解析既有 frames、替換 TIT2 / TPE1 / TALB / USLT、其餘原樣保留、
  重寫 tag 區 + 原音訊 bytes 原樣接上;約 200–300 行 Dart,無 native 依賴)。

**決定**:MP3 走自寫 ID3v2.3 writer(`id3_codec` 先驗半天,不合用就自寫),音訊 bytes 完全不動;
M4A / FLAC / OGG / Opus 走 ffmpeg `-c copy` 重新封裝。WAV 與純 AAC 也能自己寫,排第二階段:

| 格式 | 歌名 / 演出者 / 專輯 | 歌詞 | 做法 | 相容性 |
| --- | --- | --- | --- | --- |
| MP3 | ID3v2.3 TIT2 / TPE1 / TALB | USLT | 自寫 ID3 writer,替換 4 個 frame、其餘保留、音訊原樣接上 | 最好 |
| M4A / MP4 | ffmpeg `-metadata` | `©lyr` | ffmpeg `-map 0 -c copy` | 好 |
| FLAC / OGG / Opus | ffmpeg `-metadata` | Vorbis comment `LYRICS` | ffmpeg `-map 0 -c copy` | 好 |
| WAV(M2) | RIFF `LIST INFO` 的 INAM / IART / IPRD | RIFF `id3 ` chunk 內的 USLT | 重用 ID3 writer + 約 100 行 RIFF chunk 讀寫,`data` chunk 不動 | 主流工具(ffmpeg / Mp3tag / foobar2000 / MusicBee)都讀 `id3 ` chunk |
| 純 AAC / ADTS(M2) | 前置 ID3v2 | 同左 USLT | 重用 ID3 writer 直接前置 | 最弱:App 內可讀(ffprobe 會跳過前置 ID3),MediaStore 與其他播放器不保證,介面須標示 |

其他容器(WMA 等)v1 不支援,編輯頁顯示「此格式不支援編輯」。

### trackId:前置 `plans/25-path-based-track-id.md`

目前 `trackId = sha1(檔案大小 + 頭 64KB + 尾 64KB)`,tag 都在檔頭,寫 tag 必然改到 id,
封面 / 播放清單 / 統計 / 歌詞 / 佇列全部斷鏈。原本規劃寫檔後做一次 id 搬遷,
2026-09-02 決定改為**先把 trackId 換成路徑派(`plans/25`)**,改 tag 就完全不影響 id,
本計畫不再需要搬遷邏輯。本計畫以 plan 25 完成為前提。

歌詞背景工作執行中時仍禁止編輯(避免工作完成後把舊內容寫回,蓋掉使用者剛存的歌詞)。

### 歌詞來源並存:平時不回寫,只有在編輯頁按「儲存」才寫檔

既有歌詞功能(匯入 / 線上搜尋 / AI 產生 / 自動對時 / 雲端備份)仍以 `LyricsEntity` 為準,
本計畫不動它們,**也不會在背景把 DB 裡既有的歌詞 / 封面 / 任何過去資料自動寫回檔案**。
檔案唯一會被改的時機是使用者在編輯頁按「儲存」;那一刻把表單上的
**全部欄位(歌名 / 演出者 / 專輯 / 歌詞)一次寫進檔案**,不分哪個欄位有沒有改。

- 編輯頁載入:歌名 / 演出者 / 專輯帶 `Track` 目前值;歌詞欄帶 DB 內容(若有),
  否則帶檔案內嵌歌詞。
- 儲存:四個欄位整份寫入檔案;若 DB 有這首的歌詞,**一併刪除 DB 那份**
  (否則顯示端仍優先讀到舊的 DB 版本)。之後使用者再做線上搜尋 / 對時,
  結果照舊進 DB 並蓋過檔案版本(較新的動作優先)。
  這也讓「打開編輯頁、什麼都不改、直接儲存」成為把 DB 歌詞固化進檔案的明確操作。
- 顯示端優先序:**DB → 檔案內嵌 → 雲端快照**。
- 內嵌歌詞讀取:ffprobe `getTags()` 的 `lyrics` / `lyrics-xxx`(MP3 USLT 讀取 FFmpeg 早就支援)。
  ffprobe 逐檔約 50–200 ms,只在開歌詞視圖且 DB 無資料時讀一次,記憶體快取
  (key = path + size + mtime),含「讀過但沒有」的負快取;不落 Isar。
- LRC 時間標記原樣寫進 USLT / ©lyr(其他播放器也是這麼做),讀回時 `detectLyricsFormatFromContent` 判 lrc / txt。

## 設計決策

1. **只寫 tag,不轉碼**:MP3 音訊 bytes 原樣保留;M4A / FLAC 以 `-c copy -map 0` 重新封裝
   (保留內嵌封面串流)。可能遺失 ffmpeg 不認得的私有 frame / atom(接受)。
2. **先寫暫存檔再覆蓋**:iOS `rename`;Android 透過 fd 寫入(原生端),失敗時原檔不動。
3. **導頁方式與 `PlayerPage` 一致**:`Navigator.of(parentContext, rootNavigator: true)
   .push(MaterialPageRoute(fullscreenDialog: true))`,不加 go_router 路由。
4. **儲存後的刷新與播放佇列**:`musicLibraryProvider.refresh()` → 列表 / 搜尋 / 統計名稱
   自動更新(id 不變,關聯資料不用動)。若被編輯的曲目在目前播放佇列裡,佇列中的
   `MediaItem.title / artist` 仍是舊值(綁死在 `AudioSource.tag`),儲存後**以新 Track 清單
   重建佇列**:記下 index、position、是否播放中,`setAudioSource(source, initialIndex:,
   initialPosition:)` 後依原狀態續播。正在播的就是被編輯那首時會有極短暫的重新載入
   (使用者剛按了儲存,可接受),換來 App 內顯示與通知列標題一次到位。

5. **儲存 = 整份寫入**:按「儲存」時把表單四個欄位全部交給 `TrackTagWriter`,
   不做逐欄 dirty 比對;writer 替換 TIT2 / TPE1 / TALB / USLT(或對應 atom / comment),
   其餘 tag(APIC 封面、年份、曲號…)原樣保留。「儲存」一律可按;
   `PopScope` 的「放棄變更?」攔截仍以 dirty 判斷,避免沒改也被問。
6. **空欄位**:歌名必填;演出者 / 專輯留空 = 從檔案移除該 tag;歌詞留空 = 移除 USLT / ©lyr。
   每個欄位就是檔案的真實值,沒有「覆寫層」方案的三態問題。

## 警語與唯讀狀態

先不做或有平台限制的情境,不能讓使用者按了儲存才失敗。編輯頁載入時就判定狀態,
以 AppBar 下方的 `MaterialBanner`(warning 色、含 icon)顯示原因;**阻擋類**情境同時把
所有欄位設唯讀、「儲存」停用,**提醒類**情境欄位照常可編。判定邏輯集中在
`tag_edit_controller.dart` 的 `TagEditRestriction` enum,頁面只負責對應文案。

| 情境 | 判定 | 類型 | 文案(l10n key) |
| --- | --- | --- | --- |
| Android 10 以下、檔案在 SD 卡 | `Platform.isAndroid && sdkInt < 30 && !path.startsWith(primaryStorageRoot)`(primary root 由原生回傳 `Environment.getExternalStorageDirectory()`) | 阻擋 | `tag_edit_blocked_sd_card`:「這台裝置的系統版本無法修改 SD 卡上的檔案。請將檔案移到內建儲存空間後再試。」 |
| 不支援的容器(v1:WAV、純 AAC、WMA 等) | ffprobe format name 不在支援清單 | 阻擋 | `tag_edit_blocked_format`:「目前不支援編輯 {format} 格式的歌曲資訊。」 |
| 歌詞背景工作執行中(AI 產生 / 自動對時) | `lyricsActiveJobProvider(trackId)` | 阻擋 | `tag_edit_blocked_job_running`:「這首歌的歌詞正在處理中,完成後才能編輯。」 |
| 檔案不存在 / 無法讀取 | `File(path).existsSync()` 為 false | 阻擋 | `tag_edit_blocked_file_missing`:「找不到這首歌的檔案,可能已被移動或刪除。」 |
| Android 11 以上 | `sdkInt >= 30` | 提醒(只在本頁第一次進入時顯示,可關閉,SharedPreferences 記住) | `tag_edit_hint_system_dialog`:「儲存時系統會詢問是否允許修改這個檔案,請選擇允許。」 |
| 使用者在系統對話框選了拒絕 | 原生回傳 denied | 事後提示(SnackBar) | `tag_edit_write_denied`:「未取得修改權限,歌曲資訊沒有儲存。」 |
| 純 AAC(M2 開放後) | ffprobe format = aac | 提醒 | `tag_edit_hint_aac_compat`:「此格式的歌曲資訊只有部分播放器讀得到。」 |

- 阻擋類文案結尾不放「了解」按鈕,`MaterialBanner` 只留關閉;關閉後欄位仍唯讀,避免誤以為可以改。
- 「儲存」停用時 tooltip 顯示同一句原因(桌面 / 長按可見)。
- 入口(歌詞動作表單的「編輯歌曲資訊」)**不隱藏、不停用**:讓使用者進到頁面看到原因,
  比項目憑空消失清楚。

## 步驟

### M1:寫檔核心 + 編輯頁

1. **ID3 writer 驗證 / 實作**(`lib/features/tag_edit/services/id3v2_writer.dart`)
   - 先驗 `id3_codec`;不合用就自寫。單元測試:無 tag 檔、ID3v2.3、ID3v2.4、含 APIC、
     含既有 USLT 的檔各一,確認替換後其餘 frame 與音訊 bytes 完全一致。
2. **`TrackTagWriter`**(`services/track_tag_writer.dart`,一檔一 provider)
   - 依副檔名 / ffprobe 容器分派:mp3 → ID3 writer;m4a / mp4 / flac / ogg → ffmpeg;
     其餘丟 `UnsupportedFormat`。輸出到 cache 暫存檔,回傳路徑。
3. **原生寫入**(`services/track_file_replacer.dart` + `MainActivity.kt`)
   - iOS:`File.rename` 覆蓋。
   - Android:MethodChannel `replaceMediaFile(uri, tempPath)`:API 30+ 走
     `createWriteRequest`(用 `startIntentSenderForResult` 等結果)→ fd 寫入;
     API ≤ 29 走權限 + 路徑寫入;結束後 `scanFile`。
4. **佇列刷新**:`AudioPlayerService` 加 `rebuildQueue(tracks)`(保留 index / position /
   播放狀態),被編輯曲目在佇列中時呼叫。

5. **內嵌歌詞讀取**(`lib/features/lyrics/services/embedded_lyrics_service.dart`)
   - ffprobe tags → `lyrics*` key;記憶體快取;`trackLyricsProvider` 加入為第二順位。
   - `lyrics_parser.dart` 加 `detectLyricsFormatFromContent`。
6. **編輯頁**(`lib/features/tag_edit/`)
   - `tag_edit_page.dart`:AppBar(X、「編輯歌曲資訊」、「儲存」)+ 歌名 / 演出者 / 專輯
     `TextFormField`、歌詞多行 `TextField`、唯讀檔案位置;`PopScope` 攔未儲存離開;
     超過約 200 行拆 `widgets/`。
   - `providers/tag_edit_controller.dart`:載入初值、dirty、`save()` 串接
     2 → 3 → 4 → 刪 DB 歌詞 → `refresh()` → invalidate。儲存中顯示 loading 遮罩。
   - 依「警語與唯讀狀態」一節判定 `TagEditRestriction`,阻擋類欄位唯讀、儲存停用、顯示 banner。
7. **入口**:`LyricsMenuAction.editTrackInfo`,`lyricsMenuActions()` 一律附在最後
   (歌詞按鈕表單與滿版歌詞選單同時獲得);可選在 `track_actions_sheet.dart` 也加。
8. **顯示端**:`player_page.dart` AppBar、`mini_player.dart` 以 id 回查音樂庫。
9. **l10n**:`tag_edit`、`tag_edit_title`、`tag_edit_album`、`tag_edit_lyrics`、
   `tag_edit_title_required`、`tag_edit_discard_confirm`、`tag_edit_saved`、
   `tag_edit_blocked_sd_card`、`tag_edit_blocked_format`、`tag_edit_blocked_job_running`、
   `tag_edit_blocked_file_missing`、`tag_edit_hint_system_dialog`、`tag_edit_write_denied`、
   `common_save`;17 份 arb + `flutter gen-l10n`。
10. **驗證**:`flutter analyze`;實機 Android 11+ / Android 10 / iOS 各一輪:
    MP3 改四欄 → 用電腦端播放器(或 ffprobe)確認 tag;M4A / FLAC 同;
    編輯後封面 / 播放清單 / 統計仍在(id 不變);正在播放時編輯;拒絕權限對話框;
    背景對時中進編輯頁被鎖。

### M2(可選)

- SD 卡 / 路徑不可寫時退回 SAF 選檔。
- 專輯封面也在同一頁換(寫 APIC / covr),取代目前只存 App 內的自訂封面。
- WAV(RIFF INFO + `id3 ` chunk)與純 AAC(前置 ID3)寫入,重用 ID3 writer。
- 等 ffmpeg_kit 帶上含 USLT 寫入的 FFmpeg 後,評估是否移除自寫 ID3 writer。

## 邊界 / 風險

- **Android 11+ 每次儲存都彈系統對話框**:平台限制,無法免除;UI 要先說明。
- **id3_codec 品質未知**:最壞情況自寫,估 1–2 天。
- **ffmpeg 重新封裝可能掉私有 metadata**:m4a 的 iTunes 專用 atom、FLAC 的 padding 等;
  音訊本身不受影響。
- **ID3v2.4 + unsync flag / footer 的檔**:自寫 writer 一律輸出 v2.3 無 unsync,
  讀取端(MediaStore / ffprobe)相容性最好。
- **大檔寫入時間**:M4A / FLAC 重新封裝需整檔複製一次,百 MB 級 FLAC 數秒;顯示進度。
