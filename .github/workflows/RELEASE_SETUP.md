# Play Store 自動上架 + Shorebird OTA 設定

兩條出貨路徑：

- **`release.yml`** — 在 master 上推送版本 tag（`vX.Y.Z`，例如 `v1.2.13`）時觸發，
  以 `shorebird release` 建置已簽章 AAB 與 APK（同時向 Shorebird 註冊 baseline），
  AAB 上傳到 Play Store 的 internal 軌道；兩者皆上傳為 GitHub Actions artifact，
  下載連結顯示在該 run 的 summary 頁面（APK 可直接側載測試）。
- **`patch.yml`** — 僅手動觸發（`workflow_dispatch`，由 `./scripts/patch.sh` 呼叫），
  對「最新 tag 對應的 release 版本」下 `shorebird patch`，純 Dart 變更以 OTA 出貨，
  不經商店審查。

> 直接 `git push origin master` **不會**觸發任何 Shorebird 動作，
> 要出貨一定要明確跑 `release.sh` 或 `patch.sh`。

## 日常操作（用 script，不必記指令）

- **上架新版**：`./scripts/release.sh`（patch bump；也可 `minor` / `major` / 直接給 `1.4.0`）。
  會檢查 master 乾淨且同步後打 tag，並與 master 一次 atomic push，最後印出 Actions run 連結。
- **OTA 出貨**：`./scripts/patch.sh`。確認 master 已推上遠端後，
  以 `gh workflow run patch.yml` 手動觸發（需安裝並登入 gh CLI）。

## 版號規則

版號完全由 git 推導、錨定在最新 tag 的 commit（pubspec.yaml 的 `version:`
僅為 placeholder，CI 一律以 `--build-name/--build-number` 覆寫）：

- 版本號 = tag = `vX.Y.Z`（例如 `v1.2.13`），release notes 檔名與之同名
- `versionName` = 版本號去掉 `v`（`v1.2.13` → `1.2.13`），
  因 Flutter `--build-name` 與 Play Console 要求 `X.Y.Z` 數字格式，由 CI 自動處理
- `versionCode` = 到最新 tag 為止的總 commit 數（單調遞增），
  唯一用途是給 Play Console 當遞增識別碼

例：`v1.2.13` 打在第 127 個 commit → versionName `1.2.13`、versionCode `127`
（Shorebird CLI 內部以 `1.2.13+127` 格式識別此 release，僅用於 patch 指令）。

因為錨定在 tag 而非 HEAD，tag 之間的每次 push 版號不變，
patch 才有固定的 release 版本可以綁定。

## 觸發方式

```bash
# 出新 release（上架 Play Store）：在 master 最新 commit 打 tag
git tag v1.2.13
git push --atomic origin master v1.2.13

# 出 OTA patch（純 Dart 修改）：master 推上去後手動 dispatch
git push origin master
gh workflow run patch.yml --ref master
```

> - release.yml 會檢查 tag 指向的 commit 是否在 `origin/master` 上，否則中止。
> - 動到 native（gradle / AndroidManifest / 含 native code 的 plugin / Flutter 升版）
>   的變更無法 patch，patch job 會失敗——此時打新 tag 走 release。
> - 首次導入：在打出第一個以 `shorebird release` 建置的 tag 之前，
>   patch job 會因找不到 baseline 而失敗，屬預期行為。
> - 裝置需先從 Play 安裝到該 release 版本，之後才收得到對應 patch。

## 必要的 Repository Secrets

於 GitHub → Settings → Secrets and variables → Actions 新增：

| Secret | 說明 |
| --- | --- |
| `KEYSTORE_BASE64` | upload keystore（`.jks`）以 base64 編碼：`base64 -i upload-keystore.jks \| pbcopy` |
| `KEYSTORE_PASSWORD` | keystore 密碼（storePassword） |
| `KEY_ALIAS` | 金鑰別名 |
| `KEY_PASSWORD` | 金鑰密碼 |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play Console 服務帳號 JSON（`play-publisher@seek-player-f724e`；需有「發布應用程式到測試軌道」與「管理商店資訊」權限，後者供 `store-listing.yml` 更新商店文案） |
| `SHOREBIRD_TOKEN` | Shorebird CI token（console.shorebird.dev 建立 API key） |
| `APK_GCS_SERVICE_ACCOUNT` | GCP 服務帳號 `github-release-upload@seek-player-f724e.iam.gserviceaccount.com` 的 JSON key（僅有 `seek-player-f724e-apk` bucket 的 Storage Object Admin），供 CI 上傳 APK 到 GCS |

## APK 下載連結

release.yml 會把 APK 發佈到兩處：

- **Cloud Storage（主要，bucket 在 asia-east1，台灣下載快）**：
  `https://storage.googleapis.com/seek-player-f724e-apk/app-release-<版本>.apk`
  檔名帶版本號（官網知道最新版本號，組出對應連結），每版各留一份可回溯。
- **GitHub Release（備援）**：
  `https://github.com/jess0507/lyrics-player-app/releases/latest/download/app-release.apk`

bucket `seek-player-f724e-apk` 為 uniform access + `allUsers:objectViewer`
公開唯讀,與 Firebase 預設 bucket(storage.rules 管的那個)無關。
物件內容不會變,Cache-Control 為 `max-age=86400`。
曾嘗試 Firebase Hosting 方案:可行,但 252MB 的 APK 每次 deploy 都會留一版
hosting release、CLI 上傳大檔也較不穩,故改走 GCS。

### 產生 upload keystore

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## ⚠️ 上架前待辦

- 首次上架需先在 Play Console 手動建立應用並完成一次人工上傳，
  之後 `r0adkll/upload-google-play` 才能用 API 推送。
- 預設推到 `internal` 軌道；要正式發佈可把 `track` 改為 `production`。
