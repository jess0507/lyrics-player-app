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
