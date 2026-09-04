import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/backup/backup_state_store.dart';

/// 本機最後一次成功備份(上傳或還原)的時間,供備份頁顯示。
///
/// SharedPreferences 不是響應式的,所以由 GoogleDriveBackupService 在每次
/// 寫入 lastBackupAt 後呼叫 [refresh],頁面 watch 即可即時更新
/// (包含回前景的自動上傳)。
class LastBackupAtController extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.watch(backupStateStoreProvider).lastBackupAt;

  void refresh() => state = ref.read(backupStateStoreProvider).lastBackupAt;
}

final lastBackupAtProvider = NotifierProvider<LastBackupAtController, DateTime?>(
  LastBackupAtController.new,
);
