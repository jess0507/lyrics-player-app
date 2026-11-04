import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:seek_player/features/music_list/models/scanned_track.dart';
import 'package:seek_player/features/music_list/models/track_entity.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';

import '../../helpers/isar_test_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Isar isar;
  late TrackRepository repo;

  setUpAll(initializeIsarCoreForTest);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('track_repository');
    isar = await Isar.open(
      [TrackEntitySchema],
      directory: tempDir.path,
      name: 'test',
    );
    repo = TrackRepository(isar);
  });

  tearDown(() async {
    await isar.close();
    await tempDir.delete(recursive: true);
  });

  ScannedTrack scanned(
    String key, {
    String? path,
    int size = 100,
    int modifiedMs = 1,
    String? title,
  }) => ScannedTrack(
    path: path ?? '${tempDir.path}/$key.mp3',
    pathKey: key,
    sizeBytes: size,
    modifiedMs: modifiedMs,
    title: title ?? key,
  );

  test('新建時 addedAt / updatedAt 皆有值', () async {
    await repo.upsertAll([scanned('a')]);

    final entity = repo.findByPathKey('a')!;
    expect(entity.title, 'a');
    expect(entity.addedAt, entity.updatedAt);
  });

  test('同 pathKey 重掃:id 與 addedAt 不變,沒變動就不更新 updatedAt', () async {
    await repo.upsertAll([scanned('a')]);
    final first = repo.findByPathKey('a')!;

    await repo.upsertAll([scanned('a')]);
    final again = repo.findByPathKey('a')!;

    expect(again.id, first.id);
    expect(again.addedAt, first.addedAt);
    expect(again.updatedAt, first.updatedAt);
    expect(isar.trackEntitys.countSync(), 1);
  });

  test('檔案變動:只更新 metadata 與 updatedAt,保留 id / addedAt / 封面', () async {
    await repo.upsertAll([scanned('a')]);
    final first = repo.findByPathKey('a')!;
    await isar.writeTxn(() async {
      first.coverImagePath = '/covers/a.png';
      await isar.trackEntitys.putByPathKey(first);
    });

    await repo.upsertAll([scanned('a', size: 200, title: 'new title')]);
    final updated = repo.findByPathKey('a')!;

    expect(updated.id, first.id);
    expect(updated.addedAt, first.addedAt);
    expect(updated.sizeBytes, 200);
    expect(updated.title, 'new title');
    expect(updated.coverImagePath, '/covers/a.png');
  });

  test('同一次掃描重複的 pathKey 只留第一筆', () async {
    await repo.upsertAll([
      scanned('a', title: 'first'),
      scanned('a', title: 'second'),
    ]);

    expect(isar.trackEntitys.countSync(), 1);
    expect(repo.findByPathKey('a')!.title, 'first');
  });

  test('沒掃到的 pathKey 不會被刪除', () async {
    await repo.upsertAll([scanned('a'), scanned('b')]);
    await repo.upsertAll([scanned('a')]);

    expect(repo.findByPathKey('b'), isNotNull);
  });

  test('availablePathKeys:要有 entity 且檔案存在', () async {
    final existing = File('${tempDir.path}/a.mp3')..writeAsStringSync('x');
    await repo.upsertAll([
      scanned('a', path: existing.path),
      scanned('gone', path: '${tempDir.path}/gone.mp3'),
    ]);

    expect(repo.availablePathKeys(['a', 'gone', 'unknown']), {'a'});
  });
}
