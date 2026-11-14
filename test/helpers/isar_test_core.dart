import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// 在測試中載入 IsarCore 動態庫(於 `setUpAll` 呼叫一次)。
///
/// 測試 binding 會把 HttpClient 全擋成 400,Isar 內建的 download 走不通;
/// 改用 curl 預先抓 IsarCore 動態庫(只抓一次,落在 .dart_tool 下)。
/// 依平台挑對應資產:macOS 用 .dylib,Linux(CI)用 .so,否則載入會
/// 因二進位格式不符而報 invalid ELF header。
Future<void> initializeIsarCoreForTest() async {
  final String asset;
  final String ext;
  if (Platform.isMacOS) {
    asset = 'libisar_macos.dylib';
    ext = 'dylib';
  } else if (Platform.isLinux) {
    asset = 'libisar_linux_x64.so';
    ext = 'so';
  } else if (Platform.isWindows) {
    asset = 'isar_windows_x64.dll';
    ext = 'dll';
  } else {
    fail('未支援的測試平台:${Platform.operatingSystem}');
  }
  final lib = File('.dart_tool/isar_test/${Abi.current()}-libisar.$ext');
  if (!lib.existsSync()) {
    lib.parent.createSync(recursive: true);
    // flutter test 會並行跑多個測試檔:先下載到各 process 自己的暫存檔,
    // 完成後再 rename(同檔案系統內為原子操作),避免其他測試檔看到
    // 檔案已存在就載入只寫到一半的動態庫。
    final tmp = File('${lib.path}.$pid.tmp');
    final result = Process.runSync('curl', [
      '-fsSL',
      '-o',
      tmp.path,
      // isar_community 的官方二進位站(同 initializeIsarCore 的 binariesUrl)
      'https://binaries.isar-community.dev/${Isar.version}/$asset',
    ]);
    if (result.exitCode != 0) {
      if (tmp.existsSync()) tmp.deleteSync();
      fail('下載 IsarCore 失敗:${result.stderr}');
    }
    tmp.renameSync(lib.path);
  }
  await Isar.initializeIsarCore(libraries: {Abi.current(): lib.path});
}
