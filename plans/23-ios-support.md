# 23 — iOS 支援

## 背景

v1 僅支援 Android。iOS 端已有 Flutter 樣板骨架,2026-09-01 已把部署目標從 13.0 升到
15.0(Firebase iOS SDK 12.x 的最低要求),simulator debug build 可編譯、可啟動,
但 Firebase 拋 `UnsupportedError` 導致帳號/歌詞 AI/同步全部停用,且多項功能
建立在 Android-only 假設上。

## 現況盤點結論

- **可直接沿用**:isar_community、path_provider(全部走跨平台 API,無寫死路徑)、
  just_audio、fl_chart、share_plus(已處理 iPad anchor)、restart_app(iOS 分支
  已是「請手動重開」)、歌詞 generate/align 的 `_runInline` 非 Android fallback。
- **已自然降級、不 crash**:`store_update_controller`(`Platform.isAndroid` 擋掉)、
  `lyrics_background_runner`(MissingPluginException 靜默略過,iOS 走 inline)。
- **結構性阻礙**(依優先序):
  1. Firebase iOS 設定是假的(`firebase_options.dart` 對非 Android 直接 throw;
     舊 `GoogleService-Info.plist` 的 bundle id 是 `com.example.seekPlayer` 殘檔)。
  2. `Info.plist` 缺 `UIBackgroundModes: audio` 與所有 `NS*UsageDescription`
     (缺 `NSAppleMusicUsageDescription` 會在要權限時閃退)。
  3. **音樂庫來源**:整條資料鏈(內容指紋 trackId → Isar 歌詞/清單/封面/統計、
     `TrackAudioResolver`、`AudioCompressor`、分享)都吃 on_audio_query 給的
     檔案路徑 `song.data`;iOS 的 MPMediaLibrary 給不出可讀檔案路徑
     (`ipod-library://`、DRM),整條鏈會斷。
  4. Podfile 未設 permission_handler 巨集(所有權限都被編進 binary,審核風險)。
  5. ffmpeg_kit_flutter_new 目前拉 `full-gpl` variant(授權 + 審核風險)。
  6. receive_sharing_intent iOS 需 Share Extension target + App Group(未建)。
  7. CI/CD(release/patch workflow、shorebird)全為 Android。

## Phase 1 — 讓 iOS build 成為「功能完整可登入」的 app(2026-09-01 已完成)

1. **部署目標 15.0**:`ios/Podfile` 加 `platform :ios, '15.0'`;
   `project.pbxproj` 三處 `IPHONEOS_DEPLOYMENT_TARGET` 改 15.0。✅
2. **Firebase iOS app**:既有 iOS app 的 bundle id 是 `com.example.seekPlayer`
   且無法修改,故以 CLI 新建 `Seek Player iOS`
   (`1:833102634982:ios:55cdc10c66f2e6e9978027`,bundle id `com.js.seekPlayer`,
   OAuth iOS client 已自動配置)。舊的 `com.example` app 可在 Console 手動刪除。✅
3. **`lib/firebase_options.dart`**:新增 `ios` 選項並接上
   `TargetPlatform.iOS`。iOS 不像 Android 有 `.dev` 變體,debug/release 共用同一
   Firebase app。Firebase 初始化走 Dart options,不依賴 bundle 內的
   GoogleService-Info.plist(因此不需動 pbxproj 的 resources)。✅
4. **`ios/Runner/GoogleService-Info.plist`**:以新 app 的設定覆蓋殘檔
   (未加入 Xcode target,僅供人工比對;真正生效的是 firebase_options.dart)。✅
5. **`ios/Runner/Info.plist`**:補
   `UIBackgroundModes=[audio]`、`NSAppleMusicUsageDescription`、
   `NSPhotoLibraryUsageDescription`、`GIDClientID`、
   `CFBundleURLTypes`(REVERSED_CLIENT_ID,Google 登入回呼)、
   `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`
   (讓「檔案」app 能看到 Documents,替 Phase 2 匯入鋪路)、
   `ITSAppUsesNonExemptEncryption=false`。✅
6. **`ios/Podfile`**:post_install 加 permission_handler 巨集,只保留
   `PERMISSION_MEDIA_LIBRARY=1`、`PERMISSION_NOTIFICATIONS=1`。✅
7. 驗證:`flutter analyze`、simulator build + 啟動。✅

## Phase 2 — iOS 音樂庫來源(2026-09-01 已依方案 A 完成)

兩個方向(已採方案 A):

- **方案 A(建議):檔案匯入制**。iOS 不走 MPMediaLibrary,改以
  「app Documents 目錄 = 音樂庫」:file_picker 多選匯入 + 「檔案」app 直接放入
  (`UIFileSharingEnabled` 已開)+ 之後接 open-in/Share Extension。
  掃描 Documents 下的音訊檔建 `Track`,檔案路徑真實可讀 →
  內容指紋 trackId、歌詞 AI、ffmpeg 壓縮、分享全部照舊運作,
  Isar 資料模型零改動。代價:使用者要自己把檔案放進來,
  不能直接看到 Apple Music 資料庫。與 app 定位(本地檔案 + 歌詞)一致。
- **方案 B:MPMediaLibrary(on_audio_query)**。能列出系統音樂庫,
  但拿不到檔案 bytes → 指紋退化成不穩定的媒體 id、歌詞 AI /
  auto-sync / 分享全部不可用,資料層要為 iOS 另做 id 策略。不建議。

實作(檔案對應):

- `music_list/services/music_library_source.dart` — `MusicLibrarySource` 介面:
  `scan()` / `audioFilePaths()` / `pathForFallbackId()`。
- `music_list/services/media_store_music_source.dart` — Android 實作
  (原 music_library._scan 邏輯搬入;fallback id = MediaStore 數字 id)。
- `music_list/services/documents_music_source.dart` — iOS 實作:遞迴掃
  Documents(排除 `covers/`、隱藏檔,副檔名白名單限 AVPlayer 播得動的格式),
  fallback id = 檔案路徑本身。
- `music_list/services/track_metadata_service.dart` + 
  `models/track_metadata_entity.dart` — iOS 沒有 MediaStore 可查 tag,
  以 ffprobe 讀 title/artist/album/duration,(size, mtime) 條件快取於 Isar
  (與指紋快取同策略;isar_service 已註冊新 schema)。
- `music_list/services/music_import_service.dart` — 「匯入音樂」:
  file_picker 多選音訊 → 複製進 `Documents/Music/`(同名加 ` (n)`)。
- `music_list/providers/music_library_source_provider.dart` — 平台切換。
- `music_library.dart` — 掃描委派給 source;iOS 免權限直接掃。
- `permission_service.ensureAudioPermission` — iOS 直接回 true。
- `track_audio_resolver.dart` — 改走 source 介面,不再直接依賴
  on_audio_query(三段式解析邏輯不變)。
- `embedded_artwork_provider.dart` — iOS 以 ffmpeg 抽內嵌封面軌
  (輸出以 trackId 的 sha1 為 key 快取在暫存目錄);Android 維持 queryArtwork。
- `local_music_playlist_page.dart` — iOS 顯示「匯入音樂」按鈕與
  匯入導向的空狀態文案(`music_import_done` / `music_empty_import`,
  17 語系 arb 已補)。

## Phase 3 — 收尾與上架

- ffmpeg_kit_flutter_new 改用 audio/min variant(避開 GPL 與 binary size)。
- `InfoPlist.strings` 10 語系補 usage description 在地化。
- receive_sharing_intent:建 Share Extension target + App Group +
  `CFBundleDocumentTypes`(對應 Android 的 VIEW intent-filter)。
- App Check:Console 註冊 App Attest;debug 裝置註冊 debug token
  (目前後端 callable 為 warn-only,不阻擋)。
- iOS 版本檢查:`in_app_update` 無對應,改接 iTunes Lookup API 或維持 no-op。
- Isar 資料庫檔設 `NSURLIsExcludedFromBackupKey`(避免 iCloud 備份膨脹)。
- CI:新增 iOS release workflow(需 Apple 憑證/描述檔;Shorebird iOS 另評估)。

## 決策記錄

- iOS 最低版本:15.0(Firebase SDK 12.x 硬性要求)。
- iOS 不設 `.dev` bundle id 變體,debug/release 共用 `com.js.seekPlayer`
  (與 Android 不同;要分開時再加 xcconfig per-configuration bundle id)。
- Firebase 初始化採 Dart-only options,不把 GoogleService-Info.plist 編進 bundle。
