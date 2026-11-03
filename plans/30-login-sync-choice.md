# 30 - 登入時的同步方向判斷(push / pull / 詢問)

## 目標

登入成功(切到一個「這台裝置尚未綁定」的帳號)時,四個領域
(設定 / 播放清單 / 統計 / 歌詞)依「本機 / 雲端是否有資料」決定方向,
不再只比時戳:

| 本機 | 雲端 | 動作 |
|---|---|---|
| 有 | 無 | push |
| 無 | 有 | pull |
| 有 | 有 | 列入衝突,一個對話框統一問「使用雲端 / 保留本機」 |
| 無 | 無 | 不動 |

- 新帳號(雲端四個領域都沒資料):四個領域整份 push,建立雲端快照與時戳。
- 衝突對話框沿用 `CloudBackupFoundDialog`(`LinkChoice`),「更多」裡只列出
  衝突的領域。不可點外面關閉。

## 「登入」的判定

`authStateChanges` 在每次 App 啟動都會發事件,不能每次都跑上面的流程。
改在 `BackupStateStore` 記 `boundUid`(這台裝置已同步過的帳號):

- `boundUid == uid`(每次開 App、登出後再登入同一帳號):只推不拉,依時戳推本機較新的領域。原本啟動時的 `_restoreFromCloud` 已移除,雲端只在登入未綁定帳號時才會拉。
- 其餘:跑登入流程,成功後寫入 `boundUid`。
- 舊版升級:本 process 第一個 auth 事件(持久化 session)且 `boundUid == null`、
  `lastBackupAt != null` → 視為已綁定,直接寫入 `boundUid`,不跳對話框。
- 登入流程失敗(離線等)不寫 `boundUid`,下次啟動重跑。

## 「有資料」的定義

- 設定:本機 `settingModifiedAt != null`;雲端 `setting/0` 有 `settingUpdatedAt`。
- 播放清單:非系統清單,或我的最愛 / 最近播放裡有曲目(預設的空系統清單不算)。
- 統計:本機 `days` 或月加總非空;雲端 `monthlyStats` 非空。
- 歌詞:本機 repository 非空;雲端 `backupLyrics` 非空。

## 防止登入流程中途被上傳蓋掉

`_upload` 只在 `boundUid == uid` 時執行(回前景、立即同步、統計重設都會經過),
對話框開著時不會先推。登入流程本身以 `domains` 參數指定要推的領域,不走時戳判斷。

## 登入頁流程(不用全域 listener)

1. `TryToSignInView._signIn`:設 `signInInProgressProvider = true`(帳戶頁已登入也繼續
   顯示登入畫面),在同一個 `_busy` loading 內完成登入 +
   `SyncService.prepareSignInSync()`,得到 `SignInSyncPlan`(pull / push / conflicts)。
2. loading 結束、切到已登入畫面、顯示「登入成功」toast。
3. 有衝突 → 以 root Navigator 的 context 顯示 `showSyncConflictDialog`,
   使用者在 loading 期間返回或切到其他頁面也照樣顯示。
4. `SyncService.applySignInSync(plan, choice)`:套用 pull / push 並綁定 uid。
   `choice == null`(root Navigator 已不存在等極端情況)時衝突領域不動,等下次自動上傳(回前景 `_maybeUpload`)
   依時戳判斷。

其他沒有登入頁可問的情境一律走 `syncAfterSignIn()`(prepare + apply,不詢問):
手機 OTP 自動驗證、App 啟動時已登入但未綁定、未綁定時按「立即同步」。

## 檔案

- 新增 `lib/core/sync/sync_domain.dart`、`lib/core/sync/sign_in_sync_plan.dart`、
  `lib/features/profile/account/providers/sign_in_in_progress_provider.dart`、
  `lib/features/profile/backup/widgets/sync_conflict_dialog.dart`
- 修改 `sync_service.dart`、四個 `*_sync.dart`(hasLocalData / hasRemoteData)、
  `backup_state_store.dart`(boundUid)、`cloud_backup_found_dialog.dart`(items 參數)、
  `account_page.dart`、`try_to_sign_in_view.dart`(原 `signed_out_view.dart`)
