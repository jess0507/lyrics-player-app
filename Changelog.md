# Changelog

## develop
- feature
  - 底部導覽改版:工具 / 音訊 / 我的
    - 音訊:本地音樂與播放清單合併,記住上次區塊
    - 工具:工具與產出(任務、歌詞)改為卡片
- bug
  - 先上搜尋關鍵字不要省略標點符號, 可能會影響原文, ex. Don't
- enhancement
  - 更多選單:顯示搜尋等選項,讓畫面簡潔
  - player:曲目載入失敗時提示,不再丟例外
  - cover:無法解碼的圖片匯入時擋下、顯示時視為無封面
  - 檔案 / 封面選擇器防止連點重複開啟
  - lyrics:取消任務時找不到ref問題修復
  - update:回到前景時檢查熱更新
  - update:更新提示 dialog 改版
    - 加上 logo、標題、副標題
    - 主要按鈕改全寬
- analysis
  - `library_action` 新增 `switch_section`(音訊頁區塊切換)
  - crash:回報可附加資訊、可標為 fatal
    - 曲目載入失敗以 fatal 回報並附曲目資訊
    - Play 更新檢查失敗分類回報
  - 新增 `update_action` 事件
    - 商店更新:顯示 / 更新 / 稍後
    - 熱更新:顯示 / 重啟 / 稍後

## 1.2.18 patch 2(261125)
- 修正player點擊、拖曳進度條
- google play更新、熱更新dialog要點擊按鈕, 不能點擊外面關掉

## 1.2.18 patch 1(261124)
- enhancement
  - fix(audio): enable precise MP3 seeking
  - lyrics:歌詞記錄 AI 任務種類 `kind`(`generate` / `align`),並帶進 Firestore `backupLyrics`
  - tools:製作歌詞頁的「編輯歌詞」改由「歌詞預覽」標題旁的編輯鈕進入
- analysis
  - scripts:`user_stats.py` 預設排除測試帳號
  - scripts:`user_stats.py` 依 `kind` 拆 AI 產生 / 對時
  - docs:新增功能使用分析 `docs/analysis/feature-usage-2026-10-22_to_2026-11-21.md`
