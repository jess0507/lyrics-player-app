import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 離線事件匯流排:需要網路的動作偵測到離線時往這裡送一則事件,
/// 由畫面端(見 OfflineToastListener)統一顯示提示,
/// 避免每個呼叫端各自持有 context 顯示 toast。
class OfflineEventBus {
  final _controller = StreamController<int>.broadcast();

  /// 事件序號。以遞增值當 payload,讓連續兩次離線也是不同的 stream 值,
  /// 監聽端(如 Riverpod 的 ref.listen 以新舊值比對)才不會漏掉第二次。
  int _seq = 0;

  Stream<int> get stream => _controller.stream;

  void notifyOffline() => _controller.add(++_seq);

  void dispose() => _controller.close();
}

final offlineEventBusProvider = Provider<OfflineEventBus>((ref) {
  final bus = OfflineEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
