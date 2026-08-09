import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/network/offline_event_bus.dart';

/// 離線事件串流(broadcast,不保留歷史):訂閱之前送出的事件收不到,
/// 監聽端須在 app 啟動時就掛上。
final offlineEventStreamProvider = StreamProvider<int>(
  (ref) => ref.watch(offlineEventBusProvider).stream,
);
