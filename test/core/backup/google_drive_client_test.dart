import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:seek_player/core/backup/drive_backup_file.dart';
import 'package:seek_player/core/backup/google_drive_client.dart';
import 'package:seek_player/core/backup/google_drive_exception.dart';

/// 以 MockClient 驗證五個端點的請求形狀、401 重試與錯誤分類。
void main() {
  late List<http.Request> sent;
  var clearAuthCacheCalls = 0;
  var token = 't1';

  GoogleDriveClient client(
    Future<http.Response> Function(http.Request req) handler,
  ) {
    sent = [];
    clearAuthCacheCalls = 0;
    return GoogleDriveClient(
      MockClient((req) {
        sent.add(req);
        return handler(req);
      }),
      authHeaders: () async => {'Authorization': 'Bearer $token'},
      clearAuthCache: () async {
        clearAuthCacheCalls++;
        token = 't2';
      },
    );
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  http.Response driveError(int status, String reason) => json({
    'error': {
      'errors': [
        {'reason': reason},
      ],
      'code': status,
    },
  }, status);

  group('list', () {
    test('查 appDataFolder,跨頁合併,modifiedTime 缺的略過', () async {
      final c = client((req) async {
        final page = req.url.queryParameters['pageToken'];
        if (page == null) {
          return json({
            'nextPageToken': 'p2',
            'files': [
              {
                'id': '1',
                'name': 'settings.json',
                'modifiedTime': '2026-09-03T00:00:00Z',
                'appProperties': {'schemaVersion': '1'},
              },
              {'id': 'x', 'name': 'broken.json'},
            ],
          });
        }
        return json({
          'files': [
            {
              'id': '2',
              'name': 'lyrics.json',
              'modifiedTime': '2026-09-02T00:00:00Z',
            },
          ],
        });
      });
      final files = await c.list();
      expect(files.map((f) => f.id), ['1', '2']);
      expect(sent, hasLength(2));
      expect(sent.first.method, 'GET');
      expect(sent.first.url.queryParameters['spaces'], 'appDataFolder');
      expect(sent.first.headers['Authorization'], 'Bearer t1');
      expect(sent.last.url.queryParameters['pageToken'], 'p2');
    });
  });

  group('upload', () {
    final meta = {
      'id': 'new',
      'name': 'settings.json',
      'modifiedTime': '2026-09-03T01:00:00Z',
      'appProperties': {'schemaVersion': '1'},
    };

    test('新檔:先 POST metadata 拿 id,再 PATCH media 寫內容', () async {
      final c = client((req) async => json(meta));
      final file = await c.upload(
        name: 'settings.json',
        bytes: Uint8List.fromList(utf8.encode('{"a":1}')),
        schemaVersion: 1,
      );
      expect(file.id, 'new');
      expect(sent, hasLength(2));

      final create = sent[0];
      expect(create.method, 'POST');
      expect(create.url.path, '/drive/v3/files');
      final body = jsonDecode(create.body) as Map;
      expect(body['name'], 'settings.json');
      expect(body['parents'], ['appDataFolder']);
      expect(body['appProperties'], {'schemaVersion': '1'});

      final write = sent[1];
      expect(write.method, 'PATCH');
      expect(write.url.path, '/upload/drive/v3/files/new');
      expect(write.url.queryParameters['uploadType'], 'media');
      expect(write.body, '{"a":1}');
      expect(write.headers['Content-Type'], startsWith('application/json'));
    });

    test('既有檔且 schemaVersion 相同:只 PATCH media 一次', () async {
      final c = client((req) async => json(meta));
      await c.upload(
        name: 'settings.json',
        bytes: Uint8List(0),
        schemaVersion: 1,
        existing: DriveBackupFile.fromJson(meta),
      );
      expect(sent, hasLength(1));
      expect(sent.single.url.path, '/upload/drive/v3/files/new');
    });

    test('既有檔但 schemaVersion 不同:先補 metadata PATCH', () async {
      final c = client((req) async => json(meta));
      await c.upload(
        name: 'settings.json',
        bytes: Uint8List(0),
        schemaVersion: 2,
        existing: DriveBackupFile.fromJson(meta),
      );
      expect(sent, hasLength(2));
      expect(sent[0].method, 'PATCH');
      expect(sent[0].url.path, '/drive/v3/files/new');
      expect(jsonDecode(sent[0].body), {
        'appProperties': {'schemaVersion': '2'},
      });
      expect(sent[1].url.path, '/upload/drive/v3/files/new');
    });
  });

  test('download 帶 alt=media 並回 bytes', () async {
    final c = client((req) async => http.Response('hello', 200));
    final bytes = await c.download('f1');
    expect(utf8.decode(bytes), 'hello');
    expect(sent.single.url.path, '/drive/v3/files/f1');
    expect(sent.single.url.queryParameters['alt'], 'media');
  });

  group('delete', () {
    test('DELETE 204 成功', () async {
      final c = client((req) async => http.Response('', 204));
      await c.delete('f1');
      expect(sent.single.method, 'DELETE');
    });

    test('404 視為成功', () async {
      final c = client((req) async => driveError(404, 'notFound'));
      await expectLater(c.delete('gone'), completes);
    });
  });

  group('錯誤處理', () {
    test('401 → 清快取後以新 token 重試一次', () async {
      token = 't1';
      var calls = 0;
      final c = client((req) async {
        calls++;
        return calls == 1
            ? driveError(401, 'authError')
            : json({'files': <Object>[]});
      });
      await c.list();
      expect(clearAuthCacheCalls, 1);
      expect(sent[0].headers['Authorization'], 'Bearer t1');
      expect(sent[1].headers['Authorization'], 'Bearer t2');
    });

    test('連續兩次 401 → unauthorized', () async {
      final c = client((req) async => driveError(401, 'authError'));
      await expectLater(
        c.list(),
        throwsA(
          isA<GoogleDriveException>()
              .having((e) => e.kind, 'kind', GoogleDriveErrorKind.unauthorized)
              .having((e) => e.needsRelink, 'needsRelink', isTrue),
        ),
      );
      expect(sent, hasLength(2));
    });

    test('403 依 reason 分類', () async {
      for (final (reason, kind) in [
        ('insufficientPermissions', GoogleDriveErrorKind.insufficientScope),
        ('accessNotConfigured', GoogleDriveErrorKind.apiNotEnabled),
        ('storageQuotaExceeded', GoogleDriveErrorKind.quotaExceeded),
        ('somethingElse', GoogleDriveErrorKind.other),
      ]) {
        final c = client((req) async => driveError(403, reason));
        await expectLater(
          c.list(),
          throwsA(
            isA<GoogleDriveException>().having((e) => e.kind, 'kind', kind),
          ),
        );
      }
    });

    test('非 JSON 錯誤 body 不會炸,歸類 other', () async {
      final c = client((req) async => http.Response('<html>oops</html>', 500));
      await expectLater(
        c.list(),
        throwsA(
          isA<GoogleDriveException>()
              .having((e) => e.kind, 'kind', GoogleDriveErrorKind.other)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}
