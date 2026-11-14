# 41 編輯歌詞頁:字體大小、分享、開啟歌詞

## 目標
參考截圖改版「編輯歌詞」頁(`LyricsEditPage`),只加三個功能,不加其他按鈕:

1. **字體大小**:底部列按鈕,切換浮動面板(滑桿 + `−` 數值 `+`),即時改變文字框字級。
2. **分享**:底部列按鈕,以系統分享面板分享文字框內容(純文字)。
3. **開啟**:AppBar 資料夾圖示,選單兩項:
   - 開啟歌詞檔(SAF 選 `.lrc/.txt/.srt/.vtt`,讀入文字框,不直接存檔)
   - 開啟歌曲的歌詞(列出已有歌詞的曲目,選一首把它的歌詞原文讀入文字框)

另外:進頁時預先帶入本曲現有歌詞原文(原本一律空白)。

## 實作
- `LyricsImportService.pickText()`:抽出選檔 + 大小檢查 + 解碼,`importForTrack` 改用它。
- `lyrics_edit_font_size_controller.dart`:編輯頁字級(px,12–32,預設 16),存 SharedPreferences,
  與播放頁歌詞字級倍率分開。
- widgets(`lib/features/player/widgets/`):
  - `lyrics_edit_bottom_bar.dart`:分享 / 字體大小兩顆按鈕
  - `lyrics_edit_font_size_panel.dart`:浮動字級面板
  - `lyrics_edit_open_button.dart`:AppBar 開啟選單
  - `lyrics_track_picker_sheet.dart`:已有歌詞曲目清單(可搜尋)
- l10n:`lyrics_edit_open`、`lyrics_edit_open_file`、`lyrics_edit_open_track`、
  `lyrics_edit_no_tracks`、`lyrics_edit_search_hint`;分享 / 字體大小沿用 `player_share`、`lyrics_font_size`。
- analytics:`LyricsAction.editShare`、`editOpenFile`、`editOpenTrack`。

## 追加:工具分頁的獨立「編輯歌詞」項目
- `ToolKind.lyricsEdit`(路由 `/tools/lyricsEdit`),排在「製作歌詞」之後、「更改封面」之前。
- 選曲後進 `LyricsEditToolPage`(`lib/features/tools/`):查到曲目就直接顯示 `LyricsEditPage`。
- 儲存成功的 toast 移進 `LyricsEditPage`,播放頁與工具兩個入口都會提示。
- l10n:`tools_lyrics_edit_desc`。

## 追加:版面比照筆記 app
- AppBar 右側三個 icon button:復原、重做(`UndoHistoryController`)、儲存(✓)。
- 底部列由左至右:開啟(檔案)、字體大小、分享,純圖示(28)平均分布,不顯示文字。
- l10n:`common_undo`、`common_redo`(tooltip)。

## 追加:先預覽、點擊才編輯
- 已有歌詞時進頁為預覽(`TextField.readOnly`),點文字原地切成編輯(保留捲動 / 點擊位置,叫出鍵盤);
  沒有歌詞時直接編輯。
- 開啟檔案 / 歌曲的歌詞後進入編輯。
- 復原 / 重做 / 儲存只在編輯時顯示;儲存後留在本頁回到預覽(不再 pop)。

## 追加:預覽版面比照筆記 app
- AppBar 標題為歌詞名稱:預設本曲曲名;開啟檔案後為檔名(如 `A-1.lrc`);開啟其他曲目歌詞後為該曲曲名。
- 預覽時右上兩個按鈕、底部無按鈕:
  - 頁面調整(`tune`)→ 底部面板:背景顏色(跟隨主題 / 白 / 灰 / 米黃 / 淺橘 / 淺藍)、字體大小。
    背景色 `lyrics_edit_paper_color_controller.dart`(SharedPreferences),淺色紙張時文字固定深色。
  - 更多(`more_vert`)→ 分享、匯出歌詞檔(`LyricsExportService.exportText`,副檔名依內文判定)。
- 編輯時維持右上復原 / 重做 / 儲存、底部開啟 / 字體大小 / 分享。
- l10n:`lyrics_edit_page_settings`、`lyrics_edit_background`、`lyrics_edit_export`;analytics:`editExport`。

## 追加:編輯時底部精簡、工具可直接開歌詞檔
- 編輯中底部列只留字體大小、分享(純圖示 24、高度 44、上緣細分隔線);移除編輯頁的「開啟」
  (開啟歌詞檔 / 開啟歌曲的歌詞)與其選曲面板、l10n、analytics。
- 工具「編輯歌詞」選曲頁工具列原本的「從檔案選擇」按鈕改為開歌詞檔(其他工具仍選音檔):不選曲目,直接以檔案內容開
  `LyricsEditPage(trackId: null, title: 檔名, initialContent: 內容)`。
  獨立歌詞檔的 ✓ 改為另存成歌詞檔(系統存檔對話框,檔名沿用原檔名),成功後回到預覽。
- `LyricsImportService.pickFile()` 讀檔不存檔;analytics:`ToolsAction.openLyricsFile`;l10n:`lyrics_edit_open_file`。
