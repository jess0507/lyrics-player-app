# scripts/

專案的輔助 script，一律從專案根目錄執行（script 內部會自行 `cd` 到根目錄，
從其他地方執行也可以，但習慣上還是從根目錄跑）。

| Script | 用途 | 會不會觸發 CI / 出貨 |
| --- | --- | --- |
| [`release.sh`](release.sh) | 打新版本 tag 並上架 Play Store | 會，觸發 `release.yml` |
| [`patch.sh`](patch.sh) | 對最新 release 下 Shorebird OTA patch | 會，推 patch tag 觸發 `patch.yml` |
| [`gen_app_assets.sh`](gen_app_assets.sh) | 由 SVG 重新產生 App 圖示與啟動畫面 | 不會，純本機 |
| [`release_notes.py`](release_notes.py) | 把 `docs/release-notes/vX.Y.Z.md` 拆成 Play 上傳用的 whatsnew 目錄 | 不會，由 `release.sh` 與 `release.yml` 內部呼叫 |
| [`store_listing.py`](store_listing.py) | 把 `docs/store-listing/` 商店文案推到 Play Console | 會，直接改 Play Console listing（CI 也會在 push master 時自動跑） |
| [`user_stats.py`](user_stats.py) | 統計 Firebase 帳號、各使用者 App 版本與歌詞功能使用量 | 不會，唯讀查詢 |

> **直接 `git push origin master` 不會觸發任何 Shorebird / 上架動作。**
> 要出貨一定要明確跑 `release.sh` 或 `patch.sh`。
> 唯一例外是 `docs/store-listing/` 的商店文案：push master 就會由 `store-listing.yml` 自動推到 Play Console（不含 AAB）。
> 兩者都要求：在 `master` 分支、working tree 乾淨、本地不落後 `origin/master`。

**版本號慣例：** 版本號一律以 `v` 開頭（`vX.Y.Z`，例如 `v1.2.13`），git tag 與 release notes 檔名同名。
script 參數**只接受帶 `v` 的版本號**，`1.4.0` 會被拒絕。唯一例外是 Android versionName，平台要求 `X.Y.Z`，CI 會自動去掉 `v`。

---

## release.sh — 上架新版本

打一個 `vX.Y.Z` tag，並與 master 一次 atomic push 上 GitHub，
觸發 `.github/workflows/release.yml`：

1. `shorebird release` 建置已簽章的 AAB 與 APK，同時向 Shorebird 註冊這個版本為
   OTA baseline（之後的 `patch.sh` 才有目標可以 patch）。
2. AAB 上架 Play Store **production**（正式版）軌道，並把 `docs/release-notes/vX.Y.Z.md`
   （與 tag 同名）作為該版本的「這個版本有什麼新功能」一起送上去。
3. APK 上傳到 GCS 與 GitHub Release，下載連結顯示在該 run 的 summary 頁。

```bash
./scripts/release.sh           # patch bump（1.2.0 → 1.2.1）
./scripts/release.sh minor     # minor bump（1.2.0 → 1.3.0）
./scripts/release.sh major     # major bump（1.2.0 → 2.0.0）
./scripts/release.sh v1.4.0    # 直接指定版本（必須以 v 開頭）
```

指定版本時**必須帶 `v`**，`1.4.0` 會被拒絕並提示改成 `v1.4.0`。

執行前會先確認 `docs/release-notes/vX.Y.Z.md` 存在且格式正確（17 語系、每語系 ≤500 字元），
**缺檔就不打 tag**——請先用 `/release-notes vX.Y.Z` 產生並 commit。
接著印出即將使用的版本號（tag）、versionName、versionCode、commit 與版本資訊檔，
按 `y` 才會真的打 tag 並 push。

**什麼時候用：**
- 改到 native 的變更（gradle、AndroidManifest、含 native code 的 plugin、Flutter 升版），
  這類改動 Shorebird 無法 patch。
- 想讓使用者在 Play Store 看到新版本號。

**版號規則**（與 CI 相同，詳見 `.github/workflows/RELEASE_SETUP.md`）：
- 版本號 = tag = `vX.Y.Z`。
- `versionName` = 版本號去掉 `v`，因為 Flutter `--build-name` 與 Play Console 要求 `X.Y.Z` 數字格式。
- `versionCode` = 到該 tag 為止的總 commit 數，單調遞增。
- `pubspec.yaml` 的 `version:` 只是 placeholder，CI 會覆寫。

---

## patch.sh — OTA 出貨（Shorebird patch）

對「最新 `v*` tag 對應的 release 版本」下 `shorebird patch`，
純 Dart 的變更幾分鐘內就能 OTA 推到使用者手機，不經 Play Store 審查。

```bash
./scripts/patch.sh
```

流程：

1. 前置檢查（master、乾淨、不落後遠端、至少有一個 `v*` tag、HEAD 不是 tag 本身）。
2. 印出目標 release 版本與領先 tag 的 commit 數，按 `y` 確認。
3. 若本地有尚未推上去的 commit，先 `git push origin master`。
4. 打 patch tag `patch-vX.Y.Z-N` 並 push，觸發 `.github/workflows/patch.yml`。
   N 接續該版本現有 patch tag 的最大編號（例如 `patch-v1.2.18-1`、`patch-v1.2.18-2`）。

只靠 `git push`，不需要 gh CLI。patch tag 不以 `v` 開頭，
不會觸發 `release.yml`，也不影響以 `v*` tag 計算的版號。

**注意：**
- 動到 native 的變更無法 patch，CI 會偵測並失敗，此時改跑 `release.sh`。
- 最新 tag 必須已經用新版 `release.yml` 建過，否則 patch 找不到 baseline 會失敗。
- 要重跑失敗的 patch，直接再執行一次 `patch.sh` 即可（沒有新 commit 也沒關係），
  會打下一個編號的 tag；也可以在 GitHub Actions 網頁上 Re-run 失敗的 run。
- tag 的 N 是「第幾次出貨嘗試」，CI 失敗重跑後可能與 Shorebird 的 patch 編號
  （App 關於頁顯示的 `patch N`）不同。
- CI 預設推到 Shorebird 的 `stable` track；裝置下次啟動背景下載、再下次啟動生效。

---

## gen_app_assets.sh — 產生 App 圖示與啟動畫面

由 `assets/icon/app_logo.svg` 重新產生所有平台的 launcher icon 與 splash 資源。
改了 logo 之後跑一次即可。

```bash
./scripts/gen_app_assets.sh

# 覆寫 Android adaptive icon 背景色（預設 #FFFFFF）
ICON_BG="#000000" ./scripts/gen_app_assets.sh

# 調整 logo 在畫布中的大小（數字越大留白越少）
LOGO_SIZE=900 LOGO_SIZE_ANDROID12=640 ./scripts/gen_app_assets.sh
```

流程：

1. 用 Chrome headless 把 SVG 渲染成透明背景 PNG：
   - `assets/icon/app_logo.png`（1024×1024，給 launcher icon 與 splash）
   - `assets/icon/app_logo_android12.png`（1152×1152，留白較多，避開 Android 12 圓形遮罩裁切）
2. 把 `ICON_BG` 寫入 `pubspec.yaml` 的 `adaptive_icon_background`。
3. `dart run flutter_launcher_icons` 產生各平台 App 圖示。
4. `dart run flutter_native_splash:create` 產生啟動畫面資源。

**需求：** Google Chrome 或 Chromium（headless 渲染 SVG）、Flutter SDK。

產出的圖片與平台資源都會進 git，跑完記得一起 commit。

---

## release_notes.py — 版本資訊轉 Play 上傳格式

把 `docs/release-notes/vX.Y.Z.md` 的 `<語言碼>…</語言碼>` 區塊拆成
`r0adkll/upload-google-play` 需要的 `whatsnew-<語言碼>` 檔案（17 個），
拆之前會先跑 `.claude/skills/release-notes/check.py` 的格式檢查。

```bash
python3 scripts/release_notes.py docs/release-notes/v1.2.13.md build/whatsnew
```

平常不用手動跑：`release.sh` 打 tag 前用它驗格式，`release.yml` 的 deploy job 用它產生
上傳目錄。版本資訊的撰寫規範見 `docs/release-notes/README.md`。

---

## store_listing.py — 更新 Play Console 商店文案

把 `docs/store-listing/<語言>.md` 的 **App 名稱 / 簡短說明 / 完整說明** 透過
Play Developer API 推到 Play Console 各語系 listing。只更新與線上有差異的語系，
完全一致時不會建立任何變更。

```bash
python3 scripts/store_listing.py --dry-run   # 只列出哪些語系會被更新
python3 scripts/store_listing.py             # 寫入、validate、commit
```

**CI 自動執行：** `docs/store-listing/` 有變更並 push 到 `master` 時，
`.github/workflows/store-listing.yml` 會自動跑同一支 script（用 `PLAY_SERVICE_ACCOUNT_JSON` secret 認證）。
平常改完文案直接 push master 即可，不必在本機跑；本機主要用 `--dry-run` 先看差異。

**本機認證：** 不需要下載服務帳號 key，script 會用 gcloud impersonate
`play-publisher@seek-player-f724e.iam.gserviceaccount.com`。
第一次使用需先授權自己的帳號（只需一次）：

```bash
gcloud iam service-accounts add-iam-policy-binding \
  play-publisher@seek-player-f724e.iam.gserviceaccount.com \
  --project seek-player-f724e \
  --member=user:<你的 Google 帳號> \
  --role=roles/iam.serviceAccountTokenCreator
```

也可設定 `GOOGLE_APPLICATION_CREDENTIALS=<服務帳號 JSON 路徑>` 改走 key 檔（需 `pip install google-auth requests`）。

**注意：**
- 檔名 → Play 語系代碼的對應表在 script 內的 `LOCALES`（`es.md` 同時餵 `es-ES` 與 `es-419`）。
  Play Console 新增語系時要一併加上，否則該語系不會被更新。
- 字數上限（名稱 30 / 簡短說明 80 / 完整說明 4000）超過會直接失敗，不會送出任何變更。
- 服務帳號需在 Play Console「使用者和權限」擁有「管理商店資訊」權限。
- 文案變更一樣要經 Google 審查，通常數小時到數天後才會在商店頁面生效。

---

## user_stats.py — 帳號、App 版本與歌詞使用統計

唯讀查詢 Firebase Auth 帳號與 Firestore `user/{uid}` 主文件，統計：

- 帳號總數、近期新註冊、近期有登入、登入方式分佈。
- App 版本分佈（全部帳號 / 近 N 天有上傳過的帳號），含「未記錄版本」與「無主文件」。
- 歌詞功能：
  - AI 歌詞任務（`user/{uid}/lyrics` 有 `status` 的文件）：總數、近 N 天、狀態、每月任務數、用最多的帳號。
    依 `kind` 拆成 generate（AI 產生）/ align（對時），含各自的人數與近 N 天任務數；`kind` 由後端寫入，2026-11 中之前的任務沒有。
  - 歌詞備份（`user/{uid}/backupLyrics`）：目前有歌詞的歌曲數，依來源 online / generated / manual。
    `generated` 再依 `kind` 拆成 generate（AI 產生）/ align（對時）；沒有 `kind` 的是 App 加入該欄位前寫入的資料，無法區分。
  - AI 用量（`usage/{uid}`）：依月份統計分鐘數（每個帳號只留最近月份）。

```bash
python3 scripts/user_stats.py               # 統計（近期預設 30 天）
python3 scripts/user_stats.py --days 7      # 近期改為 7 天
python3 scripts/user_stats.py --list        # 加列每個帳號明細（含 email / 手機、AI 任務數、備份歌詞數、AI 用量）
python3 scripts/user_stats.py --csv out.csv # 明細輸出 CSV
python3 scripts/user_stats.py --include-test # 不排除測試帳號
```

**測試帳號：** 預設會把 `TEST_EMAILS`（定義在 script 開頭）內的帳號從所有統計、明細與 CSV 中排除，
連同它們的 Firestore 資料（主文件、AI 任務、備份歌詞、AI 用量）。要新增測試帳號就改該常數；
加 `--include-test` 可看含測試帳號的數字。

**認證：** 用目前 `gcloud` 登入帳號的 access token，需有 `seek-player-f724e` 的讀取權限。

**注意：**
- 版本由 `SyncService` 在有實際上傳時才寫入，沒資料變更的開 App 不會更新，可能落後實際安裝版本；
  v1.2.13 之前的版本不會寫。要看實際安裝分佈，以 Firebase Analytics / Crashlytics 為準。
- `lastLoginAt` 只在登入動作時更新，不代表開 App 次數。
- 備份歌詞是「目前有歌詞的歌曲數」，不是操作次數；要看線上搜尋 / 貼上等操作次數，以 Firebase Analytics 事件為準。
- `lyrics` 子集合裡沒有 `status` 的文件是舊版 client 的歌詞備份，不算任務。
- 明細含個資，CSV 不要 commit。
