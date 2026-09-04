import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/core/backup/drive_backup_file.dart';

void main() {
  test('fromJson 解析 id / name / modifiedTime(轉 UTC)/ schemaVersion', () {
    final file = DriveBackupFile.fromJson({
      'id': 'abc',
      'name': 'settings.json',
      'modifiedTime': '2026-09-03T08:10:00.000Z',
      'appProperties': {'schemaVersion': '3'},
    });
    expect(file, isNotNull);
    expect(file!.id, 'abc');
    expect(file.name, 'settings.json');
    expect(file.modifiedTime, DateTime.utc(2026, 9, 3, 8, 10));
    expect(file.schemaVersion, 3);
  });

  test('appProperties 缺或非數字 → schemaVersion null', () {
    expect(
      DriveBackupFile.fromJson({
        'id': 'a',
        'name': 'n',
        'modifiedTime': '2026-01-01T00:00:00Z',
      })!.schemaVersion,
      isNull,
    );
    expect(
      DriveBackupFile.fromJson({
        'id': 'a',
        'name': 'n',
        'modifiedTime': '2026-01-01T00:00:00Z',
        'appProperties': {'schemaVersion': 'x'},
      })!.schemaVersion,
      isNull,
    );
  });

  test('缺 id / name / modifiedTime 或格式錯 → null', () {
    expect(DriveBackupFile.fromJson({'name': 'n'}), isNull);
    expect(
      DriveBackupFile.fromJson({'id': 'a', 'name': 'n', 'modifiedTime': 'bad'}),
      isNull,
    );
  });
}
