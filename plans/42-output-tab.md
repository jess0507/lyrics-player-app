# 42 — Output 分頁

## 目標
底部導覽「播放清單」右邊新增「Output」分頁,列出各種產出集合:

- **任務**:已送出、尚未回終態的歌詞 AI 任務(產生 / 對時)。
- **歌詞**:音樂庫中有歌詞的曲目。

點集合內的曲目:以該集合為佇列播放(已是目前曲目則不重載),
把播放頁預設分頁設為滿版歌詞,再開啟播放頁。

## 實作
- 路由:新增 shell branch `/output`,子路由 `/output/tasks`、`/output/lyrics`
  (留在 shell 內,保留底部導覽列,與播放清單詳頁一致)。
- `LyricsRepository.watchAllWithContent()`:Isar 即時監聽有內容的歌詞。
- Provider(一檔一個,`lib/features/output/providers/`):
  - `lyricsEntitiesProvider`:上述 stream。
  - `outputLyricsTracksProvider`:歌詞對回音樂庫,依 `addedAt` 新到舊。
  - `outputTaskItemsProvider`:`lyricsPendingSyncStoreProvider` 對回音樂庫。
  - 對不到音樂庫的紀錄略過。
- `openTrackFullScreenLyrics()`:播放 + `setPlayerDefaultTab(fullScreenLyrics)`
  + `PlayerPageController.open`。任務尚無歌詞時播放頁走一般版面,
  歌詞頁顯示任務進度。
- GA:沿用 `PlaylistAction.playTrack`,新增 source `outputLyrics` / `outputTasks`。
- l10n:`tab_output`、`output_*` 共 7 個 key,17 種語言。分頁名稱各語言皆為 "Output"。
