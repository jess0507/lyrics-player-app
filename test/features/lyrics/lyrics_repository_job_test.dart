import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

import '../../helpers/isar_test_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Isar isar;
  late LyricsRepository repo;

  setUpAll(initializeIsarCoreForTest);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('lyrics_repository_job');
    isar = await Isar.open(
      [LyricsEntitySchema],
      directory: tempDir.path,
      name: 'test',
    );
    final prefs = await PreferencesService.create();
    repo = LyricsRepository(isar, BackupStateStore(prefs));
  });

  tearDown(() async {
    await isar.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> saveLyrics(String pathKey, String content) => repo.save(
    LyricsEntity()
      ..pathKey = pathKey
      ..title = pathKey
      ..format = LyricsFormat.txt
      ..source = LyricsSource.manual
      ..content = content
      ..addedAt = DateTime(2026),
  );

  test('beginJob 在沒有歌詞時建立空內容佔位,且不算有歌詞', () async {
    await repo.beginJob('a', jobId: 'job1', title: 'A');

    final entity = repo.findByPathKey('a')!;
    expect(entity.content, isEmpty);
    expect(entity.jobId, 'job1');
    expect(repo.getAllSync(), isEmpty);
  });

  test('beginJob 在已有歌詞時只記 jobId,內容不動', () async {
    await saveLyrics('a', 'line');
    await repo.beginJob('a', jobId: 'job1', title: 'A');

    final entity = repo.findByPathKey('a')!;
    expect(entity.content, 'line');
    expect(entity.jobId, 'job1');
  });

  test('clearJob:空內容佔位整筆刪除', () async {
    await repo.beginJob('a', jobId: 'job1', title: 'A');
    await repo.clearJob('a');

    expect(repo.findByPathKey('a'), isNull);
  });

  test('clearJob:有內容只清 jobId', () async {
    await saveLyrics('a', 'line');
    await repo.beginJob('a', jobId: 'job1', title: 'A');
    await repo.clearJob('a');

    final entity = repo.findByPathKey('a')!;
    expect(entity.content, 'line');
    expect(entity.jobId, isNull);
  });

  test('getAllSync 只回傳有內容的歌詞', () async {
    await saveLyrics('a', 'line');
    await repo.beginJob('b', jobId: 'job2', title: 'B');

    expect([for (final e in repo.getAllSync()) e.pathKey], ['a']);
  });
}
