# 線上音樂頁(MixerBox 模式)實作計畫

`lib/features/music_list/music_list_page.dart` 目前是空頁,改造為「線上音樂」頁:
YouTube 搜尋 + 熱門清單,以**官方 embed 播放器**播放影片,離開 app 時以
**畫中畫(PiP)小窗**維持播放 — 即 MixerBox(MB3)的模式。

## 方案背景與決策

評估過的路線:

| 路線 | 無廣告 | 背景播放 | 合規 / 上架風險 |
|---|---|---|---|
| YouTube 官方 embed + PiP(**本方案**) | 目前實務上幾乎無廣告,但由 YouTube 決定,不可控 | 僅 PiP 小窗;**關螢幕會停** | 符合 YouTube API ToS,可上 Play |
| YouTube 非官方抽流(youtube_explode_dart) | 保證無廣告 | 完整背景播放 | 違反 YouTube ToS,Play 有下架風險 |
| 合法替代曲庫(Audius / Jamendo / 自建) | 保證無廣告 | 完整背景播放 | 乾淨,但曲庫非主流歌曲 |

選擇本方案的前提認知(已與需求方確認):

- **無廣告不是技術保證**:embed 是否插廣告由 YouTube 依「觀看者當下 IP 地區 +
  影片版權方營利設定 + 平台政策」逐次決定。台灣目前 embed 內音樂影片幾乎不投放,
  但使用者出國(尤其美日歐)或 YouTube 調整政策(如 2024/08 調高 embed 廣告量)
  時廣告就會出現,app 端無法控制。
- **必須顯示影片畫面**:ToS 禁止純音訊/隱藏播放器。此頁是「影片播放」體驗,
  與現有 just_audio 播放鏈(mini player、通知列、歌詞、統計)平行,不共用。
- **背景極限是 PiP**:按 Home 後浮小窗續播;螢幕關閉即停,做不到鎖屏聽歌。

## 前置作業

- [ ] 到 Google Cloud Console 申請 **YouTube Data API v3** 的 API key。
  免費配額 10,000 units/天;`search.list` 一次 100 units(約 100 次搜尋/天),
  `videos.list`(熱門清單)一次 1 unit。程式先留設定位,key 不進版控。

## 實作步驟

1. **Model** — `lib/features/music_list/models/youtube_track.dart`
   `videoId / title / channelName / thumbnailUrl / duration`。
   不重用本機 `Track`(其 `filePath`、`albumId` 為 MediaStore 概念)。
2. **Service** — `lib/features/music_list/services/youtube_data_service.dart`
   以現有 `http` 套件呼叫 Data API:
   - 搜尋:`search.list`(`type=video`, `videoCategoryId=10`)
   - 熱門:`videos.list`(`chart=mostPopular`, `videoCategoryId=10`, 依地區)
   - 分頁:`pageToken`
3. **Providers**(依專案「一檔一 provider」慣例,各自成檔):
   - `providers/youtube_data_service_provider.dart`
   - `providers/online_search_query_provider.dart`
   - `providers/online_tracks_provider.dart` — AsyncNotifier;無關鍵字顯示熱門、
     有關鍵字搜尋,支援 load more。
4. **UI** — 改寫 `music_list_page.dart`:
   - AppBar 搜尋列 + 影片清單(縮圖、標題、頻道名),tile 拆至
     `widgets/online_track_tile.dart`
   - AsyncValue 三態:loading / error(可 retry)/ 資料
   - 離線時以現有 `connectivity_plus` 顯示離線提示
5. **播放視圖** — 以 `youtube_player_iframe` 內嵌**官方播放器**(合規、不抽流),
   點清單項目開啟;含標題、頻道等基本資訊。
6. **PiP** — Android `AndroidManifest.xml` 對應 activity 加
   `android:supportsPictureInPicture="true"`,以 `simple_pip_mode`(或同類套件)
   在使用者離開 app 時自動進入畫中畫續播。
7. **收尾**:
   - l10n 新增字串(搜尋 hint、離線提示、載入失敗、retry)zh / en
   - `flutter analyze`
   - 實機驗證:搜尋、熱門、播放、切出 app 進 PiP、離線提示

## 已知限制(交付時如實告知使用者)

- 廣告可能出現(地區 / 政策因素),app 無法保證無廣告。
- 關螢幕即停,無鎖屏播放。
- 搜尋配額限制:Data API 免費配額(10,000 units/天)綁**開發者 API key**,
  全體使用者共享,約等於全 app 每日 100 次搜尋。自用/小規模夠用;
  MixerBox 等大型 app 無感是因為搜尋走自建後端曲庫(只有播放才碰 YouTube),
  或已通過 Google 審查提額。若日後要放量,再評估:申請提額、
  搜尋結果快取、或搜尋改走自建後端 / 非官方搜尋端點(僅 metadata,
  風險遠低於抽流)+ 播放維持官方 embed 的混搭。
