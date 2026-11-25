---
name: changelog
description: 把尚未 push 的 commits 整理進 Changelog.md 的 `## develop` 區塊,依 feature / enhancement / analysis 分類條列。當使用者說「更新 changelog」「記到 changelog」「/changelog」時使用。只改 Changelog.md,不 commit、不 push。
---

# Changelog 流程

目標:把**還沒 push 的 commits** 濃縮成幾行,寫進根目錄 `Changelog.md` 的
`## develop` 區塊。規範與專案 `CLAUDE.md` 的「Changelog 慣例」同步,有變動時兩邊都要改。

使用者在 `/changelog` 後面帶的文字視為額外指示(例如「只記 update 相關」),
優先於下面的預設做法。

## 1. 蒐集 commits

- `git log --oneline --reverse @{u}..HEAD`;沒有 upstream 時改用 `origin/master..HEAD`。
- 沒有未 push 的 commit 就回覆「沒有尚未 push 的 commit」並結束,不要改檔。
- 只看已 commit 的內容,working tree 未 commit 的變更不記。
- 訊息看不出實際改了什麼時,用 `git show --stat <hash>` 確認。

## 2. 篩選與合併

- **略過**:`docs`、`ci`、`chore`、`test`、`refactor`、merge commit、
  `docs(changelog)` 本身——除非使用者感受得到或影響出貨流程。
- **l10n commit 不單獨成行**:併進它所屬的功能那一行。
- 同一件事的多個 commit(實作 + 後續修正 + 翻譯)合成一行。
- 已經在 `## develop` 裡的項目不要重複加;同一件事有後續 commit 時改寫原本那一行。

## 3. 分類

只用這三類,順序固定;沒有項目的類別整段省略:

| 類別 | 內容 |
| --- | --- |
| `feature` | 使用者看得到的新功能、新畫面、新入口 |
| `enhancement` | 既有功能的修正與改善:bug fix、UI 調整、效能、行為變更 |
| `analysis` | 分析事件(GA / analytics)、統計 script、分析文件 |

一個 commit 同時含功能與埋點時,拆成兩行各放一類。

## 4. 撰寫格式

```markdown
## develop
- feature
  - lyrics:支援匯入 LRC 檔
- enhancement
  - update:回到前景時檢查熱更新
- analysis
  - 新增 `update_action` 事件
    - 商店更新:顯示 / 更新 / 稍後
    - 熱更新:顯示 / 重啟 / 稍後
```

- 繁體中文,**每行盡量短**(約 30 字內),講「做了什麼」,不複述 diff、不寫 class 名稱。
- 以 `scope:` 開頭(`update`、`player`、`lyrics`、`audio`、`scripts`…),沒有合適的可省略。
- 一行講不完就拆成下一層的子條列,不要寫成長句。
- 事件名、檔名、指令用 `` ` `` 包起來。
- 不寫 commit hash、不寫日期、不寫版本號(出貨時由使用者把 `develop` 改成版本標題)。

## 5. 寫入

- 只改 `## develop` 到下一個 `## ` 之間的內容,其他版本區塊一律不動。
- 沒有 `## develop` 區塊時,在 `# Changelog` 下方新增一個。
- 區塊結尾與下一個 `## ` 標題之間保留一個空行。
- **不要** commit、push;使用者要 commit 時走 `/commit`(訊息用 `docs(changelog): ...`)。

## 6. 回報

- 列出這次新增 / 改寫的行。
- 列出略過的 commit 及原因(一行一個)。
