# 37 - 已同步歌詞也能重新對時

## 背景

歌詞可能來自線上搜尋、檔案匯入、AI 產生或手動編輯，之後也可能再被編輯過。
目前「自動對時」只在歌詞**尚未同步**時出現(`canAutoAlign = hasLyrics && !lyrics.synced`),
已同步的歌詞就算時間軸不準或文字改過，也沒辦法重新對時。

`LyricsAutoAlignService.autoAlign` 本來就會先 `parseLyrics` 再取每行純文字
(LRC 去時間戳 / 逐字標記、SRT/VTT 去時間行、txt 照換行切行),濾掉空行後送後端，
所以任何格式都已能轉成「純文字 + 換行」送去對時，限制只在 UI。

## 設計

1. **放寬條件**:`lyrics_mode_menu.dart`、`lyrics_action_tiles.dart` 的
   `canAutoAlign` 改為 `hasLyrics`。
2. **標籤**:`LyricsMenuAction.label(l10n, {synced})`,已同步時對時項目顯示
   「重新同步歌詞」(`lyrics_auto_resync`)。
3. **覆蓋確認**:`runLyricsMenuAction` 在登入 / 用量檢查之前，若目前歌詞已同步，
   先跳確認框(`lyrics_auto_resync_confirm`):會覆蓋目前時間軸並消耗用量。
   取消就不往下走。
4. **SRT/VTT 多行 cue**:cue 內多行文字解析時以 `\n` 合併成一行，送後端前改為
   依換行拆成多行，避免後端寫回 LRC 時一行內含換行。

5. **斷行交給後端**:client 不在標點處斷行，標點原樣保留送出;
   一行多句要不要拆、怎麼拆由後端處理。

## 行為說明

- 後端以「音檔 SHA-256 + 歌詞 SHA-256」判斷同一任務：文字沒改、引擎相同時直接回
  上次結果；文字改過或換引擎才會真的重新對齊。
- 段落空行對時後會消失(client 與後端都濾空行),與原本純文字對時相同。
- 失敗時保留原歌詞(既有流程)。
