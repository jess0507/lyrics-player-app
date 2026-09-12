# Release Notes(Google Play 版本資訊)

此目錄存放每個版本給 Google Play Console「這個版本有什麼新功能(What's new / Release notes)」欄位的多語言文案,一個版本一個檔案。

## 檔案
- [`v1.0.0.md`](v1.0.0.md) — 首發版本(versionCode 1)
- [`v1.2.11.md`](v1.2.11.md) — 線上歌詞搜尋／下載、內建清單、全螢幕播放器(自 v1.2.8 起的更新)
- [`v1.2.13.md`](v1.2.13.md) — 修正開啟音樂檔、推播聲音震動提醒、快進秒數與播放頁預設分頁可自訂、意見回饋與重置

## 使用方式
1. 開啟對應版本檔案,全選複製整個檔案內容。
2. 在 Play Console 的版本資訊欄位貼上;`<語言碼>...</語言碼>` 會自動分配到各語系。
3. 僅上架部分語系時,刪掉不需要的 `<語言碼>...</語言碼>` 區段即可。

## 版本檔格式規範
- 版本檔(`vX.Y.Z.md`,與 git tag 同名、帶 `v`)**只放純內容**,不加任何 Markdown 標題、說明或程式碼區塊(```),否則會被一起貼進 Play Console。
- 內容由 `<語言碼>...</語言碼>` 區塊組成,**每個開頭與結尾 tag 各自獨立一行**,內容夾在中間:
  ```
  <zh-TW>
  ...本次更新內容...
  </zh-TW>
  <en-US>
  ...content...
  </en-US>
  ```
- tag 不可與內容或其他 tag 黏在同一行,否則複製貼上會出錯。
- 語言碼與商店 listing 一致,共 17 種:zh-TW、ar、de-DE、en-US、es-419、es-ES、fr-FR、hi-IN、id、it-IT、ja-JP、ko-KR、pt-BR、ru-RU、tr-TR、vi、zh-CN。
- 每個語言內容上限 **500 個 Unicode 字元**(以 code point 計,tag 之間、去除前後空白後計)。
- 各語言描述同一批更新,僅語言不同,內容須對齊。
- 不加「本次更新帶來:」之類的引言,第一行就是第一個 `• ` 項目。
- 商店 listing(名稱/簡介/完整說明)放在 [`../store-listing/`](../store-listing/),與此處的「版本資訊」用途不同。

## 新版本流程
- 在 Claude Code 執行 `/release-notes vX.Y.Z`(版本號必填且必須以 `v` 開頭,不符就不產生;skill 定義在 `.claude/skills/release-notes/`),會依上一版 tag 以來的 git log 產生版本檔、跑格式檢查並在上方清單新增連結。
- 手動撰寫時:複製最新版本檔為 `vX.Y.Z.md`,改寫各語言的「本次更新內容」,並在上方清單新增連結,最後執行 `python3 .claude/skills/release-notes/check.py docs/release-notes/vX.Y.Z.md` 檢查格式。
