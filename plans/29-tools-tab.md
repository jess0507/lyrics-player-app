# 29 - 工具分頁(製作歌詞 / 更改封面)

## 目標
底部導覽最左邊新增「工具」分頁,集中「針對某首歌做加工」的功能入口,
不必先播放、進播放頁才找得到。之後的新工具也加在這裡。

## 流程
1. `/tools` 工具頁:列出工具(ListTile:icon + 名稱 + 說明)。
2. 點工具 → push `/tools/:tool` 選曲頁:列出本地音樂全部曲目,
   上方沿用本地音樂的資料夾篩選列(`LocalMusicFolderBar`)。
3. 點曲目 → 依工具開啟既有的底部表單:
   - 製作歌詞:`showLyricsActionsSheet`(自動產生 / 匯入 / 上網搜尋 / 同步 …,
     與播放頁同一份選單,登入 / 次數限制等 gate 一併沿用)。
   - 更改封面:新的小表單,列「新增 / 更換封面」與(有自訂封面時)「移除封面」,
     動作沿用 `setTrackCover` / `removeTrackCover`。

## 檔案
- `lib/features/tools/models/tool_kind.dart`:工具列舉(icon、文字、路由片段)。
- `lib/features/tools/tools_page.dart`:工具頁。
- `lib/features/tools/tool_track_picker_page.dart`:選曲頁。
- `lib/features/tools/widgets/cover_actions_sheet.dart`:封面動作表單。
- router 新增第一個 branch;`ScaffoldWithNav` 新增第一個 destination。
- l10n:`tab_tools`、`tools_lyrics`、`tools_lyrics_desc`、`tools_cover_desc`
  (封面標題沿用 `cover_edit`)。

## 不做
- 起始頁仍是 `/local`,不改成工具頁。
- 選曲頁暫不提供搜尋,先靠資料夾篩選縮小範圍。
