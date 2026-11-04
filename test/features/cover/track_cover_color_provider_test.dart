import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/features/cover/providers/track_cover_color_provider.dart';
import 'package:seek_player/features/cover/services/track_cover_repository.dart';
import 'package:seek_player/features/music_list/models/track_entity.dart';

import '../../helpers/isar_test_core.dart';
import '../../helpers/test_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUpAll(initializeIsarCoreForTest);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cover_color_provider');
    isar = await Isar.open(
      [TrackEntitySchema],
      directory: tempDir.path,
      name: 'test',
    );
    container = ProviderContainer(
      overrides: [isarProvider.overrideWithValue(isar)],
    );
  });

  tearDown(() async {
    container.dispose();
    await isar.close();
    await tempDir.delete(recursive: true);
  });

  TrackCoverRepository repo() => container.read(trackCoverRepositoryProvider);

  /// 封面掛在 TrackEntity 上:建一筆帶封面欄位的曲目。
  Future<void> insertTrack(
    String pathKey, {
    required String imagePath,
    int? colorValue,
  }) => isar.writeTxn(
    () => isar.trackEntitys.putByPathKey(
      TrackEntity()
        ..path = '/music/$pathKey.mp3'
        ..pathKey = pathKey
        ..sizeBytes = 0
        ..modifiedMs = 0
        ..coverImagePath = imagePath
        ..coverColorValue = colorValue
        ..addedAt = DateTime(2026)
        ..updatedAt = DateTime(2026),
    ),
  );

  Future<Color?> readColor(String pathKey) =>
      container.read(trackCoverColorProvider(pathKey).future);

  test('無封面紀錄 → null', () async {
    expect(await readColor('missing'), isNull);
  });

  test('已快取 colorValue → 直接回傳,不需讀圖檔', () async {
    await insertTrack(
      't1',
      imagePath: '${tempDir.path}/does-not-exist.png',
      colorValue: 0xFF123456,
    );

    expect(await readColor('t1'), const Color(0xFF123456));
  });

  test('未快取 → 解析圖檔取色並寫回 entity', () async {
    const blue = Color(0xFF1E5AA8);
    final file = await writeSolidColorPng('${tempDir.path}/t2.png', blue);
    await insertTrack('t2', imagePath: file.path);

    final color = await readColor('t2');

    expect(color, isNotNull);
    final cached = repo().findByPathKey('t2')!.coverColorValue;
    expect(cached, isNotNull);
    expect(cached, color!.toARGB32());
  });

  test('未快取且圖檔遺失 → null,且不寫回', () async {
    await insertTrack('t3', imagePath: '${tempDir.path}/gone.png');

    expect(await readColor('t3'), isNull);
    expect(repo().findByPathKey('t3')!.coverColorValue, isNull);
  });
}
