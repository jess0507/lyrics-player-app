import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/sync_state_store.dart';

/// 本機最後一次成功同步(上傳或還原)的時間,供備份頁顯示。
///
/// SharedPreferences 不是響應式的,所以由 SyncGoogleDriveService 在每次
/// 寫入 lastSyncAt 後呼叫 [refresh],頁面 watch 即可即時更新
/// (包含回前景的自動上傳)。
class LastSyncAtController extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.watch(syncStateStoreProvider).lastSyncAt;

  void refresh() => state = ref.read(syncStateStoreProvider).lastSyncAt;
}

final lastSyncAtProvider = NotifierProvider<LastSyncAtController, DateTime?>(
  LastSyncAtController.new,
);
