import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/features/cover/models/track_cover_entity.dart';
import 'package:seek_player/features/cover/providers/track_cover_color_provider.dart';
import 'package:seek_player/features/cover/services/track_cover_repository.dart';

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
      [TrackCoverEntitySchema],
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

  Future<Color?> readColor(String trackId) =>
      container.read(trackCoverColorProvider(trackId).future);

  test('無封面紀錄 → null', () async {
    expect(await readColor('missing'), isNull);
  });

  test('已快取 colorValue → 直接回傳,不需讀圖檔', () async {
    await repo().save(
      TrackCoverEntity()
        ..trackId = 't1'
        ..imagePath = '${tempDir.path}/does-not-exist.png'
        ..colorValue = 0xFF123456
        ..addedAt = DateTime(2026),
    );

    expect(await readColor('t1'), const Color(0xFF123456));
  });

  test('未快取 → 解析圖檔取色並寫回 entity', () async {
    const blue = Color(0xFF1E5AA8);
    final file = await writeSolidColorPng('${tempDir.path}/t2.png', blue);
    await repo().save(
      TrackCoverEntity()
        ..trackId = 't2'
        ..imagePath = file.path
        ..addedAt = DateTime(2026),
    );

    final color = await readColor('t2');

    expect(color, isNotNull);
    final cached = repo().findByTrackId('t2')!.colorValue;
    expect(cached, isNotNull);
    expect(cached, color!.toARGB32());
  });

  test('未快取且圖檔遺失 → null,且不寫回', () async {
    await repo().save(
      TrackCoverEntity()
        ..trackId = 't3'
        ..imagePath = '${tempDir.path}/gone.png'
        ..addedAt = DateTime(2026),
    );

    expect(await readColor('t3'), isNull);
    expect(repo().findByTrackId('t3')!.colorValue, isNull);
  });
}
