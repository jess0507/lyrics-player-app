---
name: commit
description: 把目前的變更整理成多個 commit:翻譯(lib/l10n)與實作分開,實作再依目的拆成數個獨立 commit。當使用者說「commit」「幫我 commit」「/commit」時使用。不 push、不切 branch、不打 tag。
---

# Commit 流程

目標:把 working tree 的變更拆成**數個各自只做一件事**的 commit,
翻譯永遠獨立且排在最前面。規範以專案 `CLAUDE.md` 的「Commit 慣例」為準,
本 skill 是其可執行版本,兩邊有變動時要同步。

使用者在 `/commit` 後面帶的文字視為額外指示(例如「只 commit 更新 dialog 的部分」
「這些合成一個就好」),優先於下面的預設拆法。

## 1. 盤點變更

一次跑完:

- `git status --short`(含 untracked)
- `git diff` 與 `git diff --cached`
- `git log --oneline -10`(對齊近期的訊息風格與 scope 命名)

沒有任何變更就回覆「沒有可 commit 的變更」並結束。
使用者已經自己 stage 了一部分時,只處理已 stage 的內容,其餘不動,並在回報中說明。

## 2. 提交前檢查

任何一項不通過就**停下來回報,不要 commit**:

- **示範 / 暫時性程式碼**:diff 中出現 `DEMO`、`TODO(demo)`、暫時的 `debugPrint`、
  強制顯示 dialog 之類的測試用程式碼 → 列出位置,問使用者要移除還是保留。
- **機密檔**:`.env`、`key.properties`、`*.jks`、`google-services.json` 以外的憑證、
  `.claude/settings.local.json` 等 → 不 commit,提醒使用者。
- **靜態檢查**:有 Dart 變更時跑 `fvm flutter analyze`,有 error / warning 就停下。
  **不要跑測試**(使用者會在 push 前自己跑)。
- **l10n 產物同步**:`.arb` 有改但 `app_localizations*.dart` 沒有對應變更時,
  先跑 `fvm flutter gen-l10n` 再繼續。

## 3. 分組

### 3.1 翻譯(永遠第一個 commit)

- 範圍:`lib/l10n/` 下的 `.arb` 與重新產生的 `app_localizations*.dart`,只有這些。
- 訊息:`feat(l10n): ...`(純修正既有譯文用 `fix(l10n): ...`)。
- 排在最前面,讓後面的實作 commit 用到的 key 已經存在。
- 多個不相干功能的字串一起改時,仍合成一個 l10n commit,訊息列出涵蓋的功能。
- 沒有翻譯變更就跳過這一步。

### 3.2 實作(盡量拆開)

其餘變更依「目的」分組,一組一個 commit。判斷準則:

- **type 不同就分開**:`feat` / `fix` / `refactor` / `docs` / `ci` / `chore` / `test`
  不混在同一個 commit。
- **scope 不同就分開**:不同 feature 目錄(`player`、`lyrics`、`update`、`audio`…)
  的變更各自成 commit;為了同一個目的而跨目錄的改動才放一起。
- **同一 scope 內,能獨立說明的也分開**:例如「新增分析事件」與「重做 dialog 版面」、
  「修 bug」與「順手的重構」。
- **該放一起的**:測試跟著它測的實作;provider 跟著第一個使用它的功能;
  檔案改名 / 搬移與因此修改的 import;文件若只是描述這次的改動,跟著該改動。
- **順序**:被依賴的先 commit(定義事件 → 使用事件;共用 widget → 使用它的頁面),
  讓每個 commit 單獨 checkout 時都不缺東西。
- **同一個檔案含兩個目的的改動**:用 `git diff <file>` 取出 patch,編輯成只含該目的的
  hunk 後以 `git apply --cached` 分次 stage(不要用互動式的 `git add -p`)。
  若兩者交錯到拆不乾淨,就合成一個 commit,並在回報中說明沒有拆的原因,不要硬拆。

不確定某個改動屬於哪一組、或拆法會影響使用者的意圖時,先列出打算的分組再問一次;
其餘情況直接執行。

## 4. 訊息格式

- `type(scope): summary`,英文、小寫開頭、祈使句、不加句號,盡量 ≤ 72 字。
- scope 用 feature 名稱(看 `git log` 既有用法:`lyrics`、`player`、`update`、`audio`、
  `l10n`、`patch`、`changelog`…);沒有合適的 scope 可省略(`ci: ...`)。
- 需要說明「為什麼」或有行為變化時加 body,一兩句即可;不要複述 diff。
- 版本號一律帶 `v`(`v1.2.18`)。
- 結尾的 attribution 依當下 session 的規定加上。

## 5. 執行

- 逐組 `git add <明確的路徑>`(不要用 `git add -A` / `git add .`)後 `git commit`。
- 每個 commit 完成後確認 `git status`,最後應該是乾淨的(除了刻意排除的檔案)。
- **不要**:push、切 branch、打 tag、`--amend`、rebase、`--no-verify`。
  使用者明確要求時才做。

## 6. 回報

列出這次建立的 commit(hash + 訊息),一行一個,依建立順序。另外說明:

- 沒有 commit 的檔案及原因。
- 沒有拆開的改動及原因。
- 目前領先遠端幾個 commit(提醒尚未 push)。
