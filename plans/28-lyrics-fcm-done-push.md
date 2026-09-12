# 歌詞任務完成以 FCM 推播即時通知(app 被滑掉也收得到)

## 背景

目前「任務完成通知」完全靠 main isolate 的 `LyricsPendingSyncService`
對 `user/{uid}/lyrics/{trackId}` 的 Firestore 即時監聽。app 被滑掉或 process
被殺後沒有人在聽,後端寫 done 也不會有通知,要等下次開 app 重新訂閱才補存
歌詞、補發通知(實測:後端 15:29 done,15:34 開 app 才收到)。

前景服務在 callable 回「已排隊」後就 stop,不會留下來等結果;讓它留著輪詢
只是把問題往後推(常駐通知、20 分鐘自停、vivo 約 60 秒切網路),不採用。

正規解法:後端在 job 轉終態時送 FCM data message,app 的背景 handler
接手存 Isar、發本機通知。**現有 Firestore 監聽路徑保留當後備**,沒有 token、
推播被系統擋、通知權限被關時仍靠它在開 app 時補回。

## 目標

- app 在前景 / 背景 / 被滑掉 / process 被殺,任一狀態下,任務 done / failed
  幾秒內就收到本機通知並把歌詞寫進 Isar。
- 同一次終態不重複發通知、不重複寫 Isar。
- 舊使用者更新後不需重新登入或任何手動動作。

## 步驟

### A. app 端:token 註冊

1. **加套件**:`firebase_messaging`(與現有 firebase_core 4.x 同代)。
   Android `AndroidManifest.xml` 不需額外設定;`POST_NOTIFICATIONS` 已宣告,
   `Permission.notification.request()` 已在啟動背景任務前呼叫。

2. **新增 `lib/core/messaging/fcm_token_service.dart`**(一檔一 provider):
   - `app.dart` 根層 `ref.watch(fcmTokenServiceProvider)` 常駐。
   - 監聽 `authStateChanges()`:
     - 有 uid → `getToken()`(try/catch:首次啟動且離線會拋,靠下一點補)後
       `_write(uid, token)`;
     - 轉為 null(登出) → 用上一個 uid 刪除自己的 devices 文件,避免同一台
       裝置換帳號後還收到舊帳號的通知。
   - 常駐監聽 `FirebaseMessaging.instance.onTokenRefresh`,有值且已登入就
     `_write`。SDK 內建網路恢復重試(`SyncTask` + connectivity receiver),
     app 端不用自己重打。
   - **每次啟動都寫一次**,不只在 refresh 時寫:token 在 app 被殺期間由 SDK
     背景拿到時,Dart 端收不到 `onTokenRefresh`,只有下次 `getToken()` 讀得到。
   - 離線時 `set` 進 Firestore 本機佇列,連線後自動送出,不需特別處理。

3. **Firestore 結構**:`user/{uid}/devices/{deviceId}`
   ```
   token:      String
   platform:   'android' | 'ios'
   locale:     String   // 目前 app 語系,後端組通知文案用(見 C-2)
   updatedAt:  serverTimestamp
   ```
   - `deviceId` 用 `FirebaseInstallations.instance.getId()`(package
     `firebase_app_installations`);一帳號多裝置各自一筆,不互蓋。
   - 不在 `user/{uid}` 主文件放單一 `fcmToken` 欄位(多裝置會互蓋)。
   - Firestore rules:`devices` 子集合僅本人可讀寫。

4. **舊使用者**:token 不是註冊時產生,是每次開 app 由 SDK 在裝置上取得。
   更新後第一次開 app 就會依步驟 2 寫入,不需遷移、不需重新登入。

### B. app 端:接收與處理

5. **前景(`onMessage`)**:直接忽略。app 活著時 Firestore 監聽會先觸發,
   走既有 `_onTerminal` → 存 Isar → 通知 + toast → 移除 pending。

6. **背景 / 被殺(`onBackgroundMessage`,top-level `@pragma('vm:entry-point')`)**:
   跑在獨立 isolate,比照 `lyricsBackgroundMain` 自建環境:
   - `Firebase.initializeApp` → `PreferencesService.create()` → `openIsar()`
     → `ProviderContainer(overrides: [...])`。
   - 讀 data payload(見 C-1):`trackId`、`status`、`mode`、`title`、
     `content`、`format`。
   - `status == done` 且 `content` 非空 → 組 `LyricsEntity`(`source:
     generated`)存 Isar;失敗只發通知。
   - 從 SharedPreferences 的 `lyrics.pendingSyncJobs` 移除 trackId
     (直接改寫 `LyricsPendingSyncStore` 用的同一個 key;背景 isolate 的
     SharedPreferences 寫檔對下次冷啟動的 main isolate 有效)。
   - 發本機通知:經 MethodChannel 呼叫 `LyricsBackgroundService.postResultNotification(
     title, text, alert = true)`,沿用 `RESULT_NOTIFICATION_ID`。
     背景 isolate 沒有 MainActivity,launcher channel 不在 → 在 native 端註冊
     一個 `FlutterPlugin` 型的 channel(不綁 Activity),或改為背景 isolate
     自己用 `flutter_local_notifications` 發。前者不加套件、與現有 Kotlin
     共用頻道 `lyrics_result`,優先。
   - 通知文案:背景 isolate 不能用 l10n resolver(要 settings provider),
     由後端依 devices 文件的 `locale` 帶好 `notificationText`(見 C-2)。

7. **去重**:
   - 通知:兩條路徑都用 `RESULT_NOTIFICATION_ID`,後到的覆蓋先到的,不會兩則。
   - Isar:`LyricsRepository.save` 依 trackId upsert,重寫同內容無害。
   - pending 清單:`remove` 冪等。下次開 app `_reconcile` 若清單已空就不會
     再訂閱;若 FCM 先到但寫檔失敗,Firestore 監聽仍會補做。
   - main isolate 的 `trackLyricsProvider` 在 FCM 背景寫 Isar 後不會自動
     invalidate;既有 `_reconcile` 不會再跑(清單已空),所以 app 從背景回
     前景時要 invalidate 一次。做法:`FcmTokenService`(或新 provider)監聽
     `AppLifecycleState.resumed` 時對 `lyricsPendingSyncStore` 重新
     `build()`,並 invalidate `trackLyricsProvider` family。簡單版:resumed
     時 `ref.invalidate(trackLyricsProvider)` 整個 family。

### C. 後端(不在本 repo,另開 issue)

1. **job 轉終態時送 FCM**:與寫 `user/{uid}/lyrics/{trackId}` 同一處。
   - 查 `user/{uid}/devices` 全部文件,對每個 token 送 data-only message:
     ```
     data: {type: 'lyrics_job', trackId, status, mode, title, format,
            content(≤ 4 KB 才內嵌;超過留空,app 端 fallback 走 Firestore 讀),
            notificationTitle, notificationText}
     android: {priority: 'high'}          // 避開 Doze 延後
     apns: {headers: {'apns-priority': '5'}, payload: {aps: {'content-available': 1}}}
     ```
   - **在 done 當下才查 token**,不在建 job 時存進 job 文件,舊版更新後只要
     done 前開過新版就收得到。
   - FCM data payload 上限 4 KB;LRC 通常 2–6 KB,超過就不帶 `content`,
     app 端背景 handler 改讀 Firestore 文件一次(此時 process 已醒,有網路)。
2. **文案**:依 devices 文件 `locale` 從後端的字串表挑
   `lyrics_ai_generate_success` 等四種;找不到回英文。
3. **清理**:送出回 `messaging/registration-token-not-registered` 或
   `invalid-argument` → 刪該 devices 文件;另排程刪 `updatedAt` 超過 60 天
   的文件(Firebase 建議的過期門檻)。

## 邊界情況

| 情境 | 結果 |
| --- | --- |
| 首次啟動離線 | `getToken()` 拋錯被吃掉;SDK 網路恢復後自動重試,`onTokenRefresh` 補寫 |
| 使用者斷網時後端 done | FCM 伺服器暫存(預設 4 週),連線後投遞 |
| 通知權限被拒 | FCM 仍收得到、Isar 仍會寫;只是沒通知,開 app 直接看到歌詞 |
| 沒有 devices 文件(從未更新新版) | 後端略過推播,走既有 Firestore 監聽後備 |
| 同裝置換帳號 | 登出時刪舊帳號 devices 文件;新帳號登入重寫 |
| OEM 強殺 process(vivo 等) | high priority data message 仍可喚醒 handler;若被 OEM 白名單擋住,退回開 app 補救 |
| iOS | 需 APNs 憑證與 `content-available`;背景 handler 不保證執行,後備路徑補 |

## 驗證

1. 送出任務 → 滑掉 app → 等後端 done → 幾秒內有通知且震動 → 開 app 歌詞已在,
   pending 清單為空,無第二則通知。
2. 同上但 app 留在前景 → 只有 toast + 一則通知(Firestore 路徑),`onMessage` 無副作用。
3. 飛航模式送出任務 → 關飛航 → 通知到達。
4. 登出 → Firestore devices 文件消失;換帳號登入 → 新文件出現。
5. 刪 app 資料重裝 → devices 出現新 token,舊 token 文件由後端清理或 60 天後過期。

## 不做

- 前景服務留著輪詢 / 監聽 Firestore 直到終態。
- 拆掉 `LyricsPendingSyncService`;它是所有 FCM 失敗情境的後備。
- 在 job 建立時把 token 存進 job 文件。
