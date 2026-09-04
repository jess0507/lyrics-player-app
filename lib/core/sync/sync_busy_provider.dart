import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 是否有同步任務(上傳 / 還原)正在執行。
class SyncBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  set busy(bool value) => state = value;
}

final syncBusyProvider = NotifierProvider<SyncBusyController, bool>(
  SyncBusyController.new,
);
