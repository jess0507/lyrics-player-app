# Seek Player

## Plan 文件慣例
- 每次擬定實作計畫(plan)時,一律存放在 `plans/` 目錄,
  以「編號-主題」命名(例如 `22-online-music-youtube-embed.md`),
  編號接續目錄內現有的最大編號。

## Import 慣例
- 專案內部檔案一律使用 `package:` import(例如
  `import 'package:seek_player/features/...';`),不使用相對路徑 import。

## Widget 檔案組織
- 當一個 widget 檔案包含多個獨立的 sub-widget,或超過約 200 行時,
  將各 sub-widget 拆到同 feature 下的 `widgets/` 子目錄,一個 widget 一個 file。
- 跨檔引用的 widget 改為 public class;僅單檔使用的 helper function 或常數維持 private。
- 拆分後在父檔以 import 組合,不改變對外行為,並以 `flutter analyze` 確認無誤。

## Provider / 狀態組織
- Provider(含其 Notifier / Controller)不與 widget 放在同一個 file。
- 嚴格一檔一 provider:每個 `final xxxProvider = ...` 各自獨立一個 file,
  包含 service 本體與其衍生 provider(例如 service provider 與其衍生的
  stream / filtered provider 也要分別成檔)。
- 檔名對應該 provider 的職責(例如 `player_sheet_controller.dart`)。

## 版本號慣例
- 專案的版本號**一律以 `v` 開頭**,形式為 `vX.Y.Z`(例如 `v1.2.12`):
  git tag、release notes 檔名(`docs/release-notes/vX.Y.Z.md`)、文件、
  對話中提到的版本號都用這個形式。
- **只接受帶 `v` 的版本號**:`v1.2.12` 原樣使用,不要再加一個 `v`;
  沒帶 `v` 的(如 `1.2.12`)視為格式錯誤直接拒絕,不要自動幫忙補 `v`。
- 唯一例外是 Android 的 versionName / pubspec `version:` / `--build-name`,
  平台要求 `X.Y.Z` 數字格式,由 CI 與 script 自動去掉 `v`,不要手動改。
- tag 由 `scripts/release.sh` 打,不要手動打 tag。

## Release Notes(Play Console 版本資訊)
- 要產生新版本的 Play Console 多語言版本資訊時,使用 `/release-notes vX.Y.Z` skill
  (定義在 `.claude/skills/release-notes/`),它會依上一版 tag 以來的 git log 產生
  `docs/release-notes/vX.Y.Z.md`、跑格式檢查並更新 README 清單。
- 版本號必填,沒帶版本號就不產生;每種語言最多 500 個 Unicode 字元。
- 格式規範以 `docs/release-notes/README.md` 為準,skill 有變動時兩邊要同步。
