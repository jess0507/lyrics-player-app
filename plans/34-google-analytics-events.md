# 34 - Google Analytics(Firebase Analytics)事件

## 背景
Firebase 後台 MAU 一直是 0,但 Play Console 有活躍資料:專案從未引入
`firebase_analytics`,Firebase 的使用者 / 活躍數全來自 Analytics SDK,
所以沒有任何資料。

## 範圍
1. 引入 `firebase_analytics`;SDK 自動事件(`first_open`、`session_start`、
   `user_engagement`)即可讓 MAU / DAU 開始有數字。
2. `screen_view`:監聽 GoRouter 的 routerDelegate,以路由樣板(`fullPath`,
   如 `/tools/:tool`)當 screen name。用 listener 而非 NavigatorObserver,
   才抓得到 StatefulShellRoute 的底部分頁切換,也不會送出含檔案路徑的實際 location。
3. user id:登入 / 登出時 `setUserId(uid)`,與 Crashlytics 一致只送 uid。
4. 登入事件:`AuthService` 各登入方式成功後,新帳號記 `sign_up`、
   既有帳號記 `login`(method:email / google / facebook / phone)。
5. 自訂事件 `lyrics_action`(參數 `action` = `LyricsMenuAction` 轉 snake_case,
   如 `auto_align_aeneas`),於 `runLyricsMenuAction` 入口記錄。

## 事件定義集中
- 所有自訂事件、參數名、登入方式集中在 `lib/core/analytics/analytics_events.dart`
  (`AnalyticsEvent` / `AnalyticsParam` / `AnalyticsSignInMethod`),呼叫端只傳 enum,
  不直接寫事件名字串。
- GA 上的名稱由 enum 識別字自動轉 snake_case;參數值傳 enum 時同樣自動轉換。
  因此改 enum 名稱等於改 GA 名稱,會讓報表斷開,命名後勿隨意更動。
- 新增事件:在 `AnalyticsEvent` 加一個值(必要時在 `AnalyticsParam` 加參數),
  呼叫 `logAnalyticsEvent(AnalyticsEvent.xxx, {AnalyticsParam.yyy: value})`。

## dev / prod
dev(`com.js.seek_player.dev`)與 prod 在同一個 Firebase 專案,GA 預設合併
各 app 統計。debug build 以 manifest meta-data
`firebase_analytics_collection_enabled=false` 關閉收集(含自動事件),
值由 `build.gradle.kts` 的 `analyticsEnabled` placeholder 控制;
要用 DebugView 驗證時暫時改成 `"true"`,並執行
`adb shell setprop debug.firebase.analytics.app com.js.seek_player.dev`。

## 隱私
事件參數只放功能層級資訊,不送 pathKey、歌名、email。

## 實作位置
- `lib/core/analytics/analytics_events.dart`:事件 / 參數 / 登入方式 enum。
- `lib/core/analytics/analytics_reporter.dart`:比照 `crash_reporter.dart`
  的 top-level 函式,Firebase 未初始化時略過。
- `lib/main.dart`:`bindAnalyticsUserId()`。
- `lib/router/app_router.dart`:`bindAnalyticsScreenTracking(router)`。
- `lib/core/auth/auth_service.dart`:`logAnalyticsSignIn`。
- `lib/features/player/widgets/lyrics_menu_action.dart`:`lyrics_action`。

## 後續可加
- 播放相關(開始播放、A-B 重複、變速)— 量大,先決定取樣 / 粒度再加。
- 工具頁(歌詞編輯、封面編輯)使用次數。
- Play Console 隱私權「資料安全性」表單需補上 Analytics 收集的資料類型。
