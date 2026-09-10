# 從檔案管理員「開啟工具」開音訊檔播放,並取得檔案路徑

## 步驟

1. **關閉 Flutter deep linking**(`android/app/src/main/AndroidManifest.xml`)
   - `<activity>` 內加 `<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>`。
     Flutter 3.27 起預設開啟,VIEW intent 的 `content://…/2/7654` 會被當成初始路由塞給 go_router 而出錯。
   - 兩個 `audio/*` VIEW intent-filter(content / file)合併成一個不寫 `scheme` 的 filter,
     系統預設同時比對 content:// 與 file://。

2. **原生端接 intent:新增 `ExternalOpenChannel.kt`**(`android/app/src/main/kotlin/com/js/seek_player/`)
   - MethodChannel `seek_player/external_open`,類別本身無狀態,`describe(intent)` 為純函式:
     只收 `type` 為 `audio/*` 的 `ACTION_VIEW`(`intent.data`)與 `ACTION_SEND`(`EXTRA_STREAM`);
     帶 `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`(從最近使用重開,系統重送原始 intent)一律略過。
   - 一律由 Dart 主動拉取(pull):Dart 呼叫 `takeLaunchIntent`,原生在主執行緒同步取走
     `activity.intent`、把 action / data / type / `EXTRA_STREAM` 清掉(保留其餘 flags / extras
     給 FlutterActivity),再到背景執行緒 `describe` 後回傳;連續呼叫只有第一次拿得到。
   - `onNewIntent(intent)` 只做 `activity.intent = intent`,不主動推送;緊接著的 onResume
     會讓 Dart 來拉。
   - **不能只在冷啟動拉**:audio_service 把 FlutterEngine 留在快取,滑掉 app 後 Activity
     銷毀但 Dart 仍活著;再從檔案開 app 只重建 Activity(重跑 `configureFlutterEngine`)
     而不重跑 Dart `main()`,原本的「Dart ready 後拉一次」永遠不會再發生,新 intent 就丟了。
   - 回傳 map:`uri`、`displayName`(`OpenableColumns.DISPLAY_NAME`)、
     `title` / `artist` / `album` / `durationMs`(`MediaMetadataRetriever`)、`filePath`(下一步)。
   - `MainActivity.kt`:`configureFlutterEngine` new 一次存進欄位;override `onNewIntent`
     呼叫 `externalOpen.onNewIntent(intent)`。

3. **原生端還原實體路徑 `resolvePath(uri): String?`**,不複製檔案,依序嘗試,第一個 `File(path).exists()` 者勝出:

   | 順序 | 情境 | 作法 |
   | --- | --- | --- |
   | 1 | `file://` | `uri.path` |
   | 2 | 任何 content URI | `contentResolver.query(uri, [MediaStore.MediaColumns.DATA])` 取 `_data` |
   | 3 | authority `com.android.externalstorage.documents` | docId `primary:Music/a.mp3` → `/storage/emulated/0/Music/a.mp3`;`<uuid>:path` → `/storage/<uuid>/path` |
   | 4 | authority `com.android.providers.media.documents` | docId `audio:1234` → 查 `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` 的 `_ID = 1234` 取 `_data` |
   | 5 | authority `com.android.providers.downloads.documents` | docId `raw:/path` 直接用;數字 id 查 `content://downloads/public_downloads/<id>` 取 `_data` |
   | 6 | 其餘 provider | 以 `DISPLAY_NAME` + `SIZE` 查 MediaStore audio,唯一命中才採用 |

4. **Dart 端改寫 `external_file_open_service.dart`**,移除 `receive_sharing_intent`
   - `Platform.isAndroid` 才啟用;`_init` 立刻 `invokeMethod('takeLaunchIntent')`(冷啟動),
     並以 `AppLifecycleListener(onResume:)` 在每次回到前景時再拉一次(背景重建 / 前景 onNewIntent)。
   - `_handle(args)`:
     1. `await ref.read(musicLibraryProvider.future)`(冷啟動掃描中要等;10 秒 timeout 或未授權就當空清單)。
     2. `filePath` 有值且 `tracks.firstWhereOrNull((t) => t.filePath == filePath)` 命中
        → `playbackController.playTrack(existing)`。
     3. 否則組暫時曲目 `playTracksAt([track], 0)`:`uri` 用原始 content URI
        (ExoPlayer 原生支援 content://,不走路徑讀檔)、`filePath` 填還原到的路徑(沒有則 `''`)、
        標題優先內嵌 tag,其次 `displayName` 去副檔名。
   - 播放失敗 `reportError` 並停留原頁;成功才開播放頁。
   - **`PlaybackController` 不可 `await _audio.play()`**:just_audio 的 `play()` Future 要等到
     播放完畢／暫停／停止才完成,await 它會把「開播放頁」卡到整首歌結束。改為 `unawaited`
     並把錯誤交給 `reportError`;載入失敗已在 `setPlaylist` 丟出。
   - `_openPlayerPage`:冷啟動時 `rootNavigatorKey.currentContext` 可能尚未就緒,
     每 50ms 輪詢至多 5 秒再 `playerPageController.open`。

5. **曲目資訊顯示路徑**(`lib/features/music_list/widgets/track_info_dialog.dart`)
   - 「位置」改顯示 `track.filePath.isNotEmpty ? track.filePath : track.uri`。

6. **pubspec**:移除 `receive_sharing_intent` 與其註解,`flutter pub get`;`flutter analyze`。

## 驗證(實機)

- Files by Google、系統「檔案」各測「開啟工具 → Seek Player」在**冷啟動 / 背景 / 前景**三種狀態:
  不出現 go_router 錯誤頁,直接播放並開啟播放頁。
- 開已在音樂庫的檔:播放頁標題、演出者、封面與從清單點播一致。
- 開不在音樂庫的檔(Download 底下未被 MediaStore 索引):仍能播放;
  曲目資訊「位置」顯示 `/storage/…` 路徑,還原不到時顯示 URI。
- 開啟後按返回鍵回到播放清單頁,不會出現空白路由。
