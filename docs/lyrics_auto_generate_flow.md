# 自動產生歌詞（Lyrics Auto Generate）流程

本文件描述「自動產生歌詞」功能從使用者點擊、Android 背景執行、系統通知,到最後結果回傳 UI 的完整流程。此功能與「自動對時（auto sync）」共用同一套背景基礎設施（`LyricsBackgroundRunner` / `LyricsBackgroundService` / 通知),差別只在 `LyricsBackgroundMode.generate` 與 `.align`。以下聚焦 `generate`。

## 一、文字流程圖

```
使用者於歌詞選單點「自動產生」
        │
        ▼
runLyricsAutoGenerate()
        │
        ├─ 同一首歌已在跑（該 trackId 的 controller state.isRunning）
        │       → 靜默直接 return，不顯示任何提示
        │
        ▼（該首歌是 idle,繼續往下)
顯示「已在背景產生」SnackBar
        │
        ▼
LyricsAutoGenerateController.run()
        │
        ├─ 非 Android ──▶ 直接在本 isolate 呼叫 LyricsAutoGenerateService.generate()
        │
        └─ Android ────▶ LyricsBackgroundRunner.run()
                                │
                                ├─ 全域已有其他任務在跑（不分哪首歌，_active != null）
                                │       → 立即回傳 busy,不呼叫 native start
                                │       → controller state = failure(error: busy)
                                │       → runLyricsAutoGenerate 顯示「忙碌中」錯誤 SnackBar
                                │
                                ▼（全域無其他任務,繼續往下)
                  MethodChannel 'lyrics_background_launcher'.start(request JSON)
                                │
                                ▼
                  MainActivity (Kotlin) → startForegroundService()
                       （native 端也再查一次 LyricsBackgroundService.isRunning,
                         已在跑則 result.success(false) → 同樣視為 busy)
                                │
                                ▼
                  LyricsBackgroundService（前景服務,dataSync）
                       建立通知（進度中,可取消）
                                │
                                ▼
                  自建 FlutterEngine.executeDartEntrypoint(lyricsBackgroundMain)
                                │
                                ▼
                  lyricsBackgroundMain（背景 isolate）
                       重建 Firebase / Auth / Isar / ProviderContainer
                                │
                                ▼
                  LyricsAutoGenerateService.generate()
                       1. 檢查登入
                       2. TrackAudioResolver 找回本機音檔
                       3. AudioCompressor 用 ffmpeg 壓成單聲道 16kHz m4a
                       4. 上傳到 Firebase Storage
                       5. 呼叫 Cloud Functions callable「generate_lyrics」(WhisperX 後端)
                       6. 取回 LRC → 寫入 Isar（LyricsRepository.save）
                                │
                     每個步驟 onStep(...) ─┬─▶ 經 IsolateNameServer port 通知 main isolate（更新 UI 狀態）
                                          └─▶ MethodChannel.invokeMethod('updateNotification') 更新系統通知文字
                                │
                                ▼
                  完成 / 失敗 / 取消 → emit(done/error/cancelled)
                       → MethodChannel 'stop'（原生發最終結果通知,並停止前景服務)
                                │
                                ▼
        main isolate：LyricsBackgroundRunner._onEvent 收到事件
                       → invalidate(trackLyricsProvider) + markLyricsModified()
                       → Completer 完成
                                │
                                ▼
        LyricsAutoGenerateController 更新 LyricsAutoGenerateState（success/failure/cancelled）
                                │
                                ▼
        UI（若 context 仍 mounted）：歌詞畫面自動重讀顯示新歌詞，或顯示錯誤 SnackBar
```

---

## 二、各步驟相關類別

### 1. 呼叫產生字幕（UI → Controller）

| 類別 / 函式 | 檔案 | 職責 |
|---|---|---|
| `LyricsMenuAction`（分派器） | `lib/features/player/widgets/lyrics_menu_action.dart` | 歌詞選單動作入口。使用者點「自動產生」時，先做登入 gate，再呼叫 `runLyricsAutoGenerate(...)`。 |
| `runLyricsAutoGenerate()` | `lib/features/player/widgets/lyrics_auto_generate_action.dart` | UI 觸發函式。**這裡的防重入檢查只看「同一首歌」**：讀 `lyricsAutoGenerateControllerProvider(trackId).isRunning`，若這首歌自己已在跑就靜默 `return`（不顯示任何提示,連 SnackBar 都不跳）。若這首歌是 idle 就會繼續往下顯示「已在背景產生」SnackBar 並呼叫 `controller.run()`；回來後**先檢查 `context.mounted`** 才讀 `ref` 或顯示錯誤，避免 widget 已 dispose 仍操作。也負責把各種 `LyricsAutoGenerateError`（含 `busy`）映射成在地化錯誤文字。 |
| `LyricsAutoGenerateController` | `lib/features/lyrics/auto_generate/lyrics_auto_generate_controller.dart` | Riverpod `NotifierProvider.family`（key 為 trackId）。管理每首曲目**各自獨立**的狀態機 `LyricsAutoGenerateState`（status: idle / running / success / failure / cancelled，含 step 與 error）；`run()` 內也有一道 `if (state.isRunning) return false`，與上面 UI 層的檢查是同一件事的雙重保險，仍只針對這首歌本身。依平台分流：Android 走 `_runInBackground()`（前景服務），其他平台走 `_runInline()`（本 isolate 直接呼叫 service）。負責先把通知文字依當前語系解析好，包進 request 傳給背景端。 |
| `LyricsAutoGenerateState` / `LyricsAutoGenerateStatus` | 同上檔案內 | 狀態 DTO，描述目前執行到哪個步驟、成功/失敗/取消。 |

> **「已有任務執行中」其實有兩層,行為不同,務必分清楚：**
> 1. **同一首歌**（`runLyricsAutoGenerate` / `controller.run()` 的 `isRunning` 檢查）→ 靜默直接返回，UI 上什麼都不會發生，也不會有錯誤訊息。
> 2. **全 app 只能跑一個背景任務**（不分是不是同一首歌）→ 由 [`LyricsBackgroundRunner`](#2-背景執行前景服務--flutterengine-背景-isolate) 的 `_active` 欄位把關，這是唯一真正限制「一次只能跑一個」的地方。若使用者對「另一首歌」發起產生，而全域已有其他曲目的任務在跑，UI 層的 per-track 檢查會放行，流程會一路呼叫到 `LyricsBackgroundRunner.run()` 才被擋下，回傳 `busy`，最後在 `runLyricsAutoGenerate` 顯示「忙碌中」的錯誤 SnackBar（**不是靜默返回**）。native 端 `LyricsBackgroundService.isRunning` 也有相同的第二道防線，避免極端 race condition 下重複啟動服務。

### 2. 背景執行（前景服務 + FlutterEngine 背景 isolate）

三方溝通協定（channel 名稱、事件格式）統一定義在 `lib/features/lyrics/background/lyrics_background_protocol.dart`：
- main isolate → native：MethodChannel `seek_player/lyrics_background_launcher`，傳 `LyricsBackgroundRequest`（JSON）啟動服務。
- native → 背景 isolate：MethodChannel `seek_player/lyrics_background`，交回同一份 JSON。
- 背景 isolate → main isolate：`IsolateNameServer` 具名 port `seek_player/lyrics_background_events`，回報 `LyricsBackgroundEvent`（type: step / done / error / cancelled）。

| 類別 | 檔案 | 職責 |
|---|---|---|
| `LyricsBackgroundRequest` / `LyricsBackgroundEvent` | `lib/features/lyrics/background/lyrics_background_protocol.dart` | 跨 isolate / 跨語言傳遞的 DTO，含 JSON 序列化，帶有各步驟已在地化好的通知文字（`stepLabels` / `cancelLabel` / `doneLabel` / `failedLabel`）。 |
| `LyricsBackgroundRunner` | `lib/features/lyrics/background/lyrics_background_runner.dart` | main isolate 端協調者（Provider）。啟動時註冊接收 port，常駐監聽背景事件；app 重啟時用 native `isRunning` 校正執行中狀態。`run()`：先要 Android 13+ 通知權限，再呼叫 `invokeMethod('start', ...)` 啟動服務，用 `Completer` 等待結果（25 分鐘 timeout 安全網）。收到 `done` 事件時，即使任務是上一個 app instance 發起的，也會 `invalidate(trackLyricsProvider)` 並 `markLyricsModified()`。一次只允許一件任務執行，否則回 `busy`。 |
| `LyricsBackgroundRunning` | `lib/features/lyrics/background/lyrics_background_running.dart` | 全域「背景任務執行中」旗標（`Notifier<bool>`），由 runner 設定；UI（歌詞選單）依此停用「自動產生／自動對時」項目，避免重複觸發。 |
| `MainActivity` | `android/app/src/main/kotlin/com/js/seek_player/MainActivity.kt` | launcher channel 的 native 端。註冊 `seek_player/lyrics_background_launcher`，處理 `start`（若 `LyricsBackgroundService.isRunning` 已為 true 則擋重複，否則 `ContextCompat.startForegroundService`）與 `isRunning` 查詢。 |
| `LyricsBackgroundService` | `android/app/src/main/kotlin/com/js/seek_player/LyricsBackgroundService.kt` | `android.app.Service` 前景服務（`foregroundServiceType="dataSync"`）。`onStartCommand` 處理 `ACTION_START` / `ACTION_CANCEL`；`start()` 呼叫 `startForeground` 並設 20 分鐘自停安全網；`startEngine()` **自建一個 `FlutterEngine`**，開 MethodChannel `seek_player/lyrics_background`，以 entrypoint `package:seek_player/features/lyrics/background/lyrics_background_main.dart` 的 `lyricsBackgroundMain` 執行背景 isolate（`executeDartEntrypoint`），並自動註冊所有 Flutter plugin（Firebase / ffmpeg_kit / isar / on_audio_query）。`cancel()` 轉呼 Dart 端 `cancel`，5 秒 grace 後強制停；`onDestroy()` 呼叫 `engine.destroy()` 中止背景 isolate（含進行中的上傳／callable 呼叫）。靜態 `isRunning` 供 `MainActivity` 判斷是否重複啟動。 |
| `lyricsBackgroundMain()` | `lib/features/lyrics/background/lyrics_background_main.dart` | `@pragma('vm:entry-point')` 背景 isolate 進入點。透過 MethodChannel 取回任務請求；**在背景 isolate 重新初始化整套環境**：`Firebase.initializeApp`、等待 `authStateChanges()` 避免誤判未登入、`PreferencesService.create()`、開 Isar、建立獨立的 `ProviderContainer`。依 `request.mode` 呼叫對應 service（generate 呼 `LyricsAutoGenerateService.generate`，align 呼 `LyricsAutoSyncService.autoSync`）。`onStep` 同時把進度 emit 給 main isolate（透過 port）並 `invokeMethod('updateNotification')` 更新系統通知文字。也註冊 `cancel` handler：收到取消時 emit(cancelled) 後請服務 `stop`。 |
| `LyricsAutoGenerateService` | `lib/features/lyrics/auto_generate/lyrics_auto_generate_service.dart` | **實際執行產生歌詞的 pipeline**，inline 模式與背景 isolate 模式共用同一份程式碼。依序：① 檢查 `FirebaseAuth.currentUser`（無 → `notLoggedIn`）；② `TrackAudioResolver.resolve(trackId)` 反查本機音檔（無 → `noAudio`）；③ `onStep(compressing)` → `AudioCompressor.compressForAlignment` 壓成單聲道 16kHz m4a；④ `onStep(uploading)` → 上傳到 Firebase Storage（`generate/{uid}/{trackId}-{timestamp}.m4a`），完成後刪暫存檔；⑤ `onStep(transcribing)` → 呼叫 Cloud Functions callable `generate_lyrics`（region `asia-east1`，timeout 10 分鐘，帶 `{bucket, object, format:'m4a'}`，不傳語言，由後端 WhisperX 自動偵測）；⑥ 取出回應中的 `lrc` 字串，寫成 `LyricsEntity`（`source=generated`, `format=lrc`），存檔並 invalidate provider。錯誤會映射成 `LyricsAutoGenerateError`（`unauthenticated`→notLoggedIn、`resource-exhausted`→rateLimited、`failed-precondition`→transcriptionFailed、`unavailable`/`deadline-exceeded`→network）。 |
| `TrackAudioResolver` | `lib/features/lyrics/services/track_audio_resolver.dart` | 由 trackId（音檔內容指紋 sha1）反查本機音檔實際路徑，依序 fallback：指紋快取 → MediaStore id → 全庫重算指紋。 |
| `AudioCompressor` | `lib/features/lyrics/auto_sync/audio_compressor.dart` | 用 ffmpeg_kit 把音檔壓成 `-ac 1 -ar 16000 -c:a aac -b:a 32k` 的 m4a，減少上傳體積；失敗拋 `AudioCompressException`。 |

> 後端 `generate_lyrics`（WhisperX ASR + 對齊）是 Firebase Cloud Functions callable，程式碼在 `functions/main.py`（Python），不在此 Flutter repo 內；Flutter 端唯一接觸點就是 `LyricsAutoGenerateService` 呼叫 callable 那一段。

### 3. Notification（系統通知）

通知**全部由原生 Kotlin（`LyricsBackgroundService.kt`）以 `NotificationCompat` 建立**，並非使用 `flutter_local_notifications`；Dart 端只透過 MethodChannel 傳文字，由 native 建立／更新／移除通知。

| 職責 | 說明 |
|---|---|
| `createChannel()`（`LyricsBackgroundService.kt`） | 建立 NotificationChannel，id 為 `lyrics_background`，名稱「Lyrics processing」，重要性 `IMPORTANCE_LOW`（避免每次更新都出聲/彈出）。 |
| `buildNotification(text)`（同上） | 建立常駐進度通知（`setOngoing(true)`, `setOnlyAlertOnce(true)`），附「取消」動作按鈕（對應 `ACTION_CANCEL`）與點擊開啟 app 的 `contentIntent`。 |
| 進度更新 | Dart 端 `lyricsBackgroundMain` 的 `onStep` 呼叫 `channel.invokeMethod('updateNotification', {text: stepLabels[step]})` → native `notify(buildNotification(text))`，固定用 `NOTIFICATION_ID = 2001` 更新同一則通知。 |
| 結果通知 | 任務結束時 Dart 端呼叫 `stop`（帶 `doneLabel` 或 `failedLabel` 文字）→ native `postResultNotification(text)`，用獨立的 `RESULT_NOTIFICATION_ID = 2002`、`setAutoCancel(true)`（使用者可滑掉）。若是使用者主動取消，則不帶文字，故不會再發一則結果通知。 |
| 通知文字在地化 | 由發起端 `LyricsAutoGenerateController` 先用當前語系解析好各階段／取消／完成／失敗字串，塞進 `LyricsBackgroundRequest` 的 `stepLabels` / `cancelLabel` / `doneLabel` / `failedLabel`，背景 isolate 與 native 端都不用再處理 i18n。 |

### 4. 最後處理回應（結果回傳 UI / 存檔 / 錯誤處理）

| 類別 | 檔案 | 職責 |
|---|---|---|
| `LyricsEntity` | `lib/features/lyrics/models/lyrics_entity.dart` | Isar `@collection`，以 `trackId` 為唯一索引（upsert/replace）。產生成功的歌詞會存成 `source=generated`, `format=lrc`。 |
| `LyricsRepository` | `lib/features/lyrics/services/lyrics_repository.dart` | `save()` 對 `LyricsEntity` 做 upsert，並呼叫 `markLyricsModified()` 觸發 SyncService 把歌詞備份到雲端（`users/{uid}/lyrics/{trackId}`）。此步驟發生在**背景 isolate**內。 |
| `LyricsBackgroundRunner._onEvent`（`lyrics_background_runner.dart`） | 同上 | main isolate 收到背景 isolate 傳回的 `done` 事件後，**再次**呼叫 `invalidate(trackLyricsProvider)` 與 `markLyricsModified()`（因為背景 isolate 與 main isolate 是各自獨立的 Dart VM，provider 快取不會互通），接著讓等待中的 `Completer` 完成。 |
| `trackLyricsProvider` | `lib/features/lyrics/providers/track_lyrics_provider.dart` | `FutureProvider.family<Lyrics?, String>`。被 invalidate 後重新讀取 Isar 並解析歌詞內容，畫面自動切到剛產生好的同步 LRC。 |
| `LyricsAutoGenerateController`（結果回填） | `lib/features/lyrics/auto_generate/lyrics_auto_generate_controller.dart` | `_runInBackground` 依 `Completer` 回傳的 `result.status`（success / cancelled / busy / failure）更新 `LyricsAutoGenerateState`，failure 時附上 `LyricsAutoGenerateError`。 |
| 錯誤上報 | `LyricsAutoGenerateService` / `lyricsBackgroundMain` | Service 層對 compress / upload / callable / 回應解析等各自呼叫一次 `reportError`（Crashlytics）；`LyricsBackgroundRunner` 收到 `error` 事件時**刻意不重複上報**，只有背景 isolate 端遇到「非預期例外」才會再報一次，避免同一錯誤被記錄兩次。 |
| `context.mounted` 檢查 | `lib/features/player/widgets/lyrics_auto_generate_action.dart` | `await controller.run(...)` 回來後先 `if (!context.mounted) return;` 才讀 `ref` 或顯示 SnackBar；因背景任務可能跑數分鐘，期間使用者很可能已離開該頁面，結果已經由系統通知回報過，此處只是收尾。歌詞選單的登入 gate 也有同樣的 `context.mounted` 檢查。 |

---

## 附註

- `LyricsAutoGenerateService` 是 inline（非 Android）與背景（Android）兩種執行路徑共用的同一份業務邏輯，差別只在「誰呼叫它」與「跑在哪個 isolate」。
- 背景基礎設施（`LyricsBackgroundRunner` / `LyricsBackgroundService` / `lyricsBackgroundMain` / 通知）同時服務「自動產生」與「自動對時」兩種模式（`LyricsBackgroundMode.generate` / `.align`），新增其他背景任務可考慮沿用同一套協定，而非另起爐灶。
