import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/sync_state_store.dart';

/// 備份頁顯示用:本機最後一次成功同步(上傳或還原)的時間,取自
/// SyncStateStore,與 Drive 寫入同一時刻,不需另外向 Drive 讀取。
///
/// SharedPreferences 的值不是響應式的,用 autoDispose 讓頁面離開時釋放、
/// 下次打開重新讀取;同步動作結束後由呼叫端 invalidate 刷新。
final lastSyncAtProvider = Provider.autoDispose<DateTime?>(
  (ref) => ref.watch(syncStateStoreProvider).lastSyncAt,
);
