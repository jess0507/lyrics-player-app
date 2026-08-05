import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/profile/statistics/models/daily_track_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/models/period_stat_entity.dart';
import 'package:seek_player/features/profile/statistics/services/statistics_service.dart';

DailyTrackStatEntity _stat(
  String day,
  String trackId,
  int playCount,
  int listenMs,
) {
  return DailyTrackStatEntity()
    ..day = day
    ..trackId = trackId
    ..title = 'T$trackId'
    ..playCount = playCount
    ..listenMs = listenMs;
}

PeriodStatEntity? _month(Isar isar, String period) =>
    isar.periodStatEntitys.getByPeriodSync(period);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUpAll(() async {
    // 測試 binding 會把 HttpClient 全擋成 400,Isar 內建的 download 走不通;
    // 改用 curl 預先抓 IsarCore 動態庫(只抓一次,落在 .dart_tool 下)。
    // 依平台挑對應資產:macOS 用 .dylib,Linux(CI)用 .so,否則載入會
    // 因二進位格式不符而報 invalid ELF header。
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
      final result = Process.runSync('curl', [
        '-fsSL',
        '-o',
        lib.path,
        // isar_community 的官方二進位站（同 initializeIsarCore 的 binariesUrl）
        'https://binaries.isar-community.dev/${Isar.version}/$asset',
      ]);
      if (result.exitCode != 0) {
        fail('下載 IsarCore 失敗:${result.stderr}');
      }
    }
    await Isar.initializeIsarCore(libraries: {Abi.current(): lib.path});
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_test');
    isar = await Isar.open(
      [DailyTrackStatEntitySchema, PeriodStatEntitySchema],
      directory: tempDir.path,
      name: 'test',
    );
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      isarProvider.overrideWithValue(isar),
      preferencesServiceProvider
          .overrideWithValue(await PreferencesService.create()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await isar.close();
    await tempDir.delete(recursive: true);
  });

  StatisticsController controller() =>
      container.read(statisticsControllerProvider.notifier);

  test('寫入後月總量與明細同交易成對累加（day 數據即明細，不另存）', () {
    const track =
        Track(id: '1', uri: 'file:///a', filePath: '/a', title: 'A');
    final c = controller();
    c.recordPlay(track);
    c.addListenTime(track, const Duration(seconds: 5));
    c.recordPlay(
        const Track(id: '2', uri: 'file:///b', filePath: '/b', title: 'B'));

    final month = StatisticsController.monthKey(DateTime.now());
    final monthTotal = _month(isar, month)!;
    expect(monthTotal.playCount, 2);
    expect(monthTotal.listenMs, 5000);

    // 與明細加總一致。
    final details = isar.dailyTrackStatEntitys.where().findAllSync();
    expect(details.fold(0, (s, d) => s + d.playCount), monthTotal.playCount);
    expect(details.fold(0, (s, d) => s + d.listenMs), monthTotal.listenMs);
  });

  test('v2 文件還原（無 monthlyTotals）：月總量由明細重建', () {
    controller().restoreFromRemote([
      _stat('2026-04-10', '1', 2, 100),
      _stat('2026-04-20', '1', 1, 40),
      _stat('2026-05-01', '1', 1, 30),
    ]);
    // 明細直接落地（day 數據就在這裡）。
    expect(isar.dailyTrackStatEntitys.countSync(), 3);
    // 月總量由明細加總重建。
    expect(_month(isar, '2026-04')!.playCount, 3);
    expect(_month(isar, '2026-04')!.listenMs, 140);
    expect(_month(isar, '2026-05')!.playCount, 1);
  });

  test('v3 文件還原：月粒度以雲端為準、明細直接落地', () {
    // 雲端 month total 比明細加總大——模擬明細已被截斷、
    // 歷史總量只剩 monthlyTotals 保有的情境。
    controller().restoreFromRemote(
      [_stat('2026-05-20', '1', 1, 30)],
      monthlyTotals: [
        PeriodStatEntity()
          ..period = '2026-05'
          ..playCount = 9
          ..listenMs = 999,
      ],
    );
    expect(isar.dailyTrackStatEntitys.getByDayTrackIdSync('2026-05-20', '1')!
        .listenMs, 30);
    final month = _month(isar, '2026-05')!;
    expect(month.playCount, 9);
    expect(month.listenMs, 999);
  });

  test('還原整份覆寫：既有明細與月總量先被清空', () {
    controller().restoreFromRemote([_stat('2026-01-01', '9', 5, 500)]);
    controller().restoreFromRemote([_stat('2026-02-02', '1', 1, 10)]);
    expect(_month(isar, '2026-01'), isNull);
    expect(_month(isar, '2026-02')!.playCount, 1);
    expect(isar.dailyTrackStatEntitys.countSync(), 1);
  });

  test('reset 同交易清空明細與月總量兩個 collection', () {
    controller()
        .recordPlay(const Track(id: '1', uri: 'u', filePath: '/a', title: 'A'));
    controller().reset();
    expect(isar.dailyTrackStatEntitys.countSync(), 0);
    expect(isar.periodStatEntitys.countSync(), 0);
  });

  test('recomputePeriods 由明細重算指定日所屬月份', () {
    final c = controller();
    isar.writeTxnSync(() => isar.dailyTrackStatEntitys.putAllSync([
          _stat('2026-06-01', '1', 3, 200),
          _stat('2026-06-02', '1', 2, 100),
          _stat('2026-05-30', '1', 4, 400),
        ]));
    c.recomputePeriods(['2026-06-01']);
    // 6 月由整月明細重算（含未列在 dayKeys 的 06-02）。
    expect(_month(isar, '2026-06')!.playCount, 5);
    expect(_month(isar, '2026-06')!.listenMs, 300);
    // 未受影響的月份不重算。
    expect(_month(isar, '2026-05'), isNull);
  });
}
