import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/network/offline_event_bus.dart';
import 'package:seek_player/core/network/network_status_service.dart';

/// 需要網路的動作在進入流程前先呼叫本函式守門:離線時回傳 false,
/// 呼叫端直接中止。提示不在這裡顯示,而是往 [OfflineEventBus] 送一則
/// 離線事件,由掛在 app 根層的 OfflineToastListener 統一顯示 toast。
///
/// 兩個 provider 都在 await 之前先 read,呼叫端 widget 在等待期間
/// unmount 也不會踩到「已 dispose 的 ref」。
Future<bool> ensureOnline(WidgetRef ref) async {
  final status = ref.read(networkStatusServiceProvider);
  final bus = ref.read(offlineEventBusProvider);
  final online = await status.isOnline();
  if (!online) bus.notifyOffline();
  return online;
}
