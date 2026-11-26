# 43 — Output 併入工具分頁

## Context
Output 的內容(任務、歌詞)都是先用「工具」才會產生,單獨佔一個底部導覽太浪費,
而且兩頁內容都很少(工具 3 項、Output 2 個集合)。改成工具頁一頁分兩區:
上半「工具」、下半「產出」,底部導覽從 4 個減為 3 個。

## 版面
```
AppBar: 工具
  製作歌詞 / 編輯歌詞 / 更改封面   (原 ListTile 不變;AppBar 已是「工具」,不另加標題)
  產出                         (titleSmall 標題,樣式同最近播放的日期標題)
  任務  N 首
  歌詞  N 首
```

## 實作
- 新增 `lib/features/output/widgets/output_collections_section.dart`:
  原 `OutputPage` 的集合清單抽成 `OutputCollectionsSection`,接在 `ToolsPage` 的 ListView 尾端。
- 刪除 `lib/features/output/output_page.dart`。
- 路由:移除 `/output` shell branch;集合清單頁改為 `/tools/output/tasks`、
  `/tools/output/lyrics`,留在 shell 內保留底部導覽,排在 `:tool` 之前。
- 底部導覽移除 Output,剩 工具 / 媒體庫 / 我的。
- l10n:`tab_output` 改名為 `output_section`(各語言翻譯沿用,zh_TW「產出」)。
- GA:screen_view 用路由樣板,集合頁的 screen name 由 `/output/*` 變為 `/tools/output/*`。

## 驗證
- `flutter analyze`。
- 實機:底部導覽剩 3 個;工具頁兩區顯示、任務/歌詞曲數正確;
  點集合進清單頁、底部導覽仍在、返回回工具頁;點工具仍進選曲頁(全螢幕)。
