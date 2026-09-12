# scripts/

專案的輔助 script，一律從專案根目錄執行（script 內部會自行 `cd` 到根目錄，
從其他地方執行也可以，但習慣上還是從根目錄跑）。

| Script | 用途 | 會不會觸發 CI / 出貨 |
| --- | --- | --- |
| [`release.sh`](release.sh) | 打新版本 tag 並上架 Play Store | 會，觸發 `release.yml` |
| [`patch.sh`](patch.sh) | 對最新 release 下 Shorebird OTA patch | 會，手動觸發 `patch.yml` |
| [`gen_app_assets.sh`](gen_app_assets.sh) | 由 SVG 重新產生 App 圖示與啟動畫面 | 不會，純本機 |

> **直接 `git push origin master` 不會觸發任何 Shorebird / 上架動作。**
> 要出貨一定要明確跑 `release.sh` 或 `patch.sh`。
> 兩者都要求：在 `master` 分支、working tree 乾淨、本地不落後 `origin/master`。

**版本號慣例：** 版本號一律以 `v` 開頭（`vX.Y.Z`，例如 `v1.2.13`），git tag 與 release notes 檔名同名。
script 參數**只接受帶 `v` 的版本號**，`1.4.0` 會被拒絕。唯一例外是 Android versionName，平台要求 `X.Y.Z`，CI 會自動去掉 `v`。

---

## release.sh — 上架新版本

打一個 `vX.Y.Z` tag，並與 master 一次 atomic push 上 GitHub，
觸發 `.github/workflows/release.yml`：

1. `shorebird release` 建置已簽章的 AAB 與 APK，同時向 Shorebird 註冊這個版本為
   OTA baseline（之後的 `patch.sh` 才有目標可以 patch）。
2. AAB 上架 Play Store **internal** 軌道。
3. APK 上傳到 GCS 與 GitHub Release，下載連結顯示在該 run 的 summary 頁。

```bash
./scripts/release.sh           # patch bump（1.2.0 → 1.2.1）
./scripts/release.sh minor     # minor bump（1.2.0 → 1.3.0）
./scripts/release.sh major     # major bump（1.2.0 → 2.0.0）
./scripts/release.sh v1.4.0    # 直接指定版本（必須以 v 開頭）
```

指定版本時**必須帶 `v`**，`1.4.0` 會被拒絕並提示改成 `v1.4.0`。

執行前會印出即將使用的版本號（tag）、versionName、versionCode 與 commit，
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
4. 以 `gh workflow run patch.yml --ref master` 手動觸發 `.github/workflows/patch.yml`。

**需求：** 已安裝並登入 [gh CLI](https://cli.github.com/)（`brew install gh && gh auth login`）。

**注意：**
- 動到 native 的變更無法 patch，CI 會偵測並失敗，此時改跑 `release.sh`。
- 最新 tag 必須已經用新版 `release.yml` 建過，否則 patch 找不到 baseline 會失敗。
- 要重跑失敗的 patch，直接再執行一次 `patch.sh` 即可（沒有新 commit 也沒關係）。
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
