import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/sync_state_store.dart';

/// 帳戶頁面顯示用:本機最後一次成功上傳同步的時間(取自 SyncStateStore,
/// 與雲端寫入同一時刻,不需另外向 Firestore 讀取)。
///
/// SharedPreferences 的值不是響應式的,用 autoDispose 讓頁面離開時釋放、
/// 下次打開重新讀取,避免整個 App session 都停在第一次讀到的舊值。
final lastSyncAtProvider = Provider.autoDispose<DateTime?>(
  (ref) => ref.watch(syncStateStoreProvider).lastSyncAt,
);
