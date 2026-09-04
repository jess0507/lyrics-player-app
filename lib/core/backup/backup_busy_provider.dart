import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 是否有備份任務(上傳 / 還原)正在執行。
class BackupBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  set busy(bool value) => state = value;
}

final backupBusyProvider = NotifierProvider<BackupBusyController, bool>(
  BackupBusyController.new,
);
