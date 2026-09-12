---
name: release-notes
description: 產生 Google Play「版本資訊」多語言文案(docs/release-notes/X.Y.Z.md),必須帶版本號參數。當使用者要「產生 release notes」「寫版本資訊」「準備 Play Console what's new」時使用。
---

# Release Notes 產生流程

目標:在 `docs/release-notes/` 新增一個版本檔,內容可直接整檔複製貼到
Play Console「這個版本有什麼新功能」欄位。格式規範以 `docs/release-notes/README.md` 為準,
本 skill 是其可執行版本。

## 1. 版本號(必填)

- 版本號**必須由使用者指定**,格式 `X.Y.Z`(例如 `/release-notes 1.2.12`)。
- 沒有帶版本號、或格式不是 `X.Y.Z` 時,**不要產生任何檔案**,只回覆:
  「請帶版本號,例如 `/release-notes 1.2.12`」,然後結束。
- 不要自行從 git tag 推斷版本。

檔名為 `docs/release-notes/X.Y.Z.md`(**不加 `v`**)。
若檔案已存在,先讀出來,改寫而非重建。

## 2. 蒐集本版變更

- 唯一來源是 git 歷史。先找出上一個版本檔對應的 tag:
  `docs/release-notes/` 內最大的既有版本號 `A.B.C`(不含本次要產生的檔),對應 tag `vA.B.C`。
- 執行 `git log vA.B.C..HEAD --oneline`(若 tag `vX.Y.Z` 已存在,改用 `vA.B.C..vX.Y.Z`)。
  找不到任何既有版本檔時,用 `git describe --tags --abbrev=0 --match 'v*'` 取最新 tag 作為起點。
- 忽略 `localization`、`chore`、`refactor`、`test`、`docs`、merge 類 commit,
  只留使用者可感知的功能與修正。commit 訊息不清楚時,用 `git show --stat <hash>` 看改了哪些 feature 目錄。
- 過去版本檔(例如 `1.2.11.md`)當語氣與用詞範本。

## 3. 撰寫規則

- 從 commit 的開發者用語轉成**使用者視角**:講「能做什麼」,不講 class、provider、Firestore 路徑。
- 先寫 `zh-TW` 定稿,再翻成其他 16 種語言;各語言描述同一批項目,順序一致。
- **不加引言**(不要「本次更新帶來:」之類的開頭句),第一行就是第一個項目;每項一行,以 `• ` 開頭,6 項左右為宜。
- 字母系語言(es/fr/it/de/pt)通常比英文長 15~20%,英文請控制在 420 字元內,才有餘裕。
- 每個語言內容 **最多 500 個 Unicode 字元**(以 code point 計,一個中文字、一個 emoji、一個 `•` 各算 1;tag 之間、去除前後空白後計)。太長就合併或刪次要項目,所有語言同步刪。
- 語言碼順序固定:zh-TW、ar、de-DE、en-US、es-419、es-ES、fr-FR、hi-IN、id、it-IT、ja-JP、ko-KR、pt-BR、ru-RU、tr-TR、vi、zh-CN。
- 檔案**只放純內容**:沒有 Markdown 標題、說明、程式碼區塊。
- 每個 `<語言碼>` 與 `</語言碼>` 各自獨立一行,tag 不可與內容黏在同一行。
- App 名稱、功能名稱對照 `docs/store-listing/<語言>.md` 的用詞,保持一致。

## 4. 驗證

寫完後執行(從專案根目錄):

```
python3 .claude/skills/release-notes/check.py docs/release-notes/X.Y.Z.md
```

會檢查:17 種語言齊全且順序正確、tag 獨立成行、無 Markdown 標題/程式碼區塊、每語言最多 500 個 Unicode 字元。
有錯就修到全部通過,並把每種語言的字數摘要回報給使用者。

## 5. 更新 README 清單

在 `docs/release-notes/README.md` 的「## 檔案」清單**最下方**新增一行,格式:

```
- [`X.Y.Z.md`](X.Y.Z.md) — 一句話摘要本版重點
```

## 6. 收尾

- 不 commit,不打 tag(那是 `scripts/release.sh` 的事)。
- 回報:新增/修改了哪些檔案、各語言字數、有無因超長而刪掉的項目。
