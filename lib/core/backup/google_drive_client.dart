import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:seek_player/core/backup/drive_backup_file.dart';
import 'package:seek_player/core/backup/google_drive_account.dart';
import 'package:seek_player/core/backup/google_drive_exception.dart';

/// Google Drive `appDataFolder` 專用的最小 REST client:列出 / 上傳 /
/// 下載 / 刪除,直接用 `http` 打五個端點,不引入 googleapis。
///
/// Authorization header 每次請求向 [authHeaders] 取(google_sign_in 會自動
/// 換新 access token);拿到 401 時呼叫 [clearAuthCache] 後重試一次。
class GoogleDriveClient {
  GoogleDriveClient(
    this._http, {
    required Future<Map<String, String>> Function() authHeaders,
    required Future<void> Function() clearAuthCache,
  }) : _authHeaders = authHeaders,
       _clearAuthCache = clearAuthCache;

  final http.Client _http;
  final Future<Map<String, String>> Function() _authHeaders;
  final Future<void> Function() _clearAuthCache;

  static const _apiBase = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadBase = 'https://www.googleapis.com/upload/drive/v3/files';
  static const _fileFields = 'id,name,modifiedTime,appProperties';
  static const _space = 'appDataFolder';

  static const _metadataTimeout = Duration(seconds: 30);
  static const _transferTimeout = Duration(minutes: 3);

  /// 列出 appDataFolder 內全部檔案(含分頁)。`modifiedTime` 缺漏的項目略過。
  Future<List<DriveBackupFile>> list() async {
    final files = <DriveBackupFile>[];
    String? pageToken;
    do {
      final uri = Uri.parse(_apiBase).replace(
        queryParameters: {
          'spaces': _space,
          'fields': 'nextPageToken,files($_fileFields)',
          'pageSize': '100',
          'pageToken': ?pageToken,
        },
      );
      final res = await _send('GET', uri, timeout: _metadataTimeout);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      for (final item in (json['files'] as List? ?? const [])) {
        if (item is! Map<String, dynamic>) continue;
        final file = DriveBackupFile.fromJson(item);
        if (file != null) files.add(file);
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null);
    return files;
  }

  /// 上傳 [bytes] 為 appDataFolder 內名為 [name] 的檔案。
  ///
  /// [existing] 為 null 時先建檔(只帶 metadata)拿 id,再以
  /// `uploadType=media` 寫內容(兩步省掉手刻 multipart);已存在時直接
  /// 覆寫內容,schemaVersion 有變才另補一次 metadata PATCH。
  /// 回傳寫入後的 metadata(`modifiedTime` 即本次上傳的伺服器時間)。
  Future<DriveBackupFile> upload({
    required String name,
    required Uint8List bytes,
    required int schemaVersion,
    DriveBackupFile? existing,
    String contentType = 'application/json',
  }) async {
    final props = {DriveBackupFile.schemaVersionKey: '$schemaVersion'};
    var id = existing?.id;
    if (id == null) {
      final res = await _send(
        'POST',
        Uri.parse(_apiBase).replace(queryParameters: {'fields': _fileFields}),
        headers: const {'Content-Type': 'application/json'},
        body: utf8.encode(
          jsonEncode({
            'name': name,
            'parents': const [_space],
            'appProperties': props,
          }),
        ),
        timeout: _metadataTimeout,
      );
      id = (jsonDecode(res.body) as Map<String, dynamic>)['id'] as String;
    } else if (existing!.schemaVersion != schemaVersion) {
      await _send(
        'PATCH',
        Uri.parse('$_apiBase/$id'),
        headers: const {'Content-Type': 'application/json'},
        body: utf8.encode(jsonEncode({'appProperties': props})),
        timeout: _metadataTimeout,
      );
    }
    final res = await _send(
      'PATCH',
      Uri.parse('$_uploadBase/$id').replace(
        queryParameters: {'uploadType': 'media', 'fields': _fileFields},
      ),
      headers: {'Content-Type': contentType},
      body: bytes,
      timeout: _transferTimeout,
    );
    final file = DriveBackupFile.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
    if (file == null) {
      throw GoogleDriveException(
        GoogleDriveErrorKind.other,
        res.statusCode,
        '上傳回應缺 metadata:${res.body}',
      );
    }
    return file;
  }

  /// 下載檔案內容。
  Future<Uint8List> download(String id) async {
    final res = await _send(
      'GET',
      Uri.parse('$_apiBase/$id').replace(queryParameters: {'alt': 'media'}),
      timeout: _transferTimeout,
    );
    return res.bodyBytes;
  }

  /// 刪除檔案;檔案已不存在(404)視為成功。
  Future<void> delete(String id) async {
    try {
      await _send(
        'DELETE',
        Uri.parse('$_apiBase/$id'),
        timeout: _metadataTimeout,
      );
    } on GoogleDriveException catch (e) {
      if (e.kind != GoogleDriveErrorKind.notFound) rethrow;
    }
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    List<int>? body,
    required Duration timeout,
  }) async {
    var res = await _sendOnce(method, uri, headers, body, timeout);
    if (res.statusCode == 401) {
      debugPrint('[Drive] 401,清 token 快取後重試一次');
      await _clearAuthCache();
      res = await _sendOnce(method, uri, headers, body, timeout);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw _classify(res);
  }

  Future<http.Response> _sendOnce(
    String method,
    Uri uri,
    Map<String, String>? headers,
    List<int>? body,
    Duration timeout,
  ) async {
    final req = http.Request(method, uri)
      ..headers.addAll(await _authHeaders())
      ..headers.addAll(headers ?? const {});
    if (body != null) req.bodyBytes = body;
    final streamed = await _http.send(req).timeout(timeout);
    return http.Response.fromStream(streamed).timeout(timeout);
  }

  static GoogleDriveException _classify(http.Response res) {
    final reason = _errorReason(res.body);
    final kind = switch (res.statusCode) {
      401 => GoogleDriveErrorKind.unauthorized,
      403 when reason == 'insufficientPermissions' =>
        GoogleDriveErrorKind.insufficientScope,
      403 when reason == 'accessNotConfigured' =>
        GoogleDriveErrorKind.apiNotEnabled,
      403 when reason == 'storageQuotaExceeded' =>
        GoogleDriveErrorKind.quotaExceeded,
      404 => GoogleDriveErrorKind.notFound,
      _ => GoogleDriveErrorKind.other,
    };
    return GoogleDriveException(
      kind,
      res.statusCode,
      reason == null ? res.body : '$reason: ${res.body}',
    );
  }

  /// Drive 錯誤 body 形狀:`{"error":{"errors":[{"reason":"..."}],...}}`。
  static String? _errorReason(String body) {
    try {
      final json = jsonDecode(body);
      final errors = (json as Map)['error']['errors'];
      if (errors is List && errors.isNotEmpty) {
        return (errors.first as Map)['reason'] as String?;
      }
    } catch (_) {
      // 非 JSON(例如 HTML 錯誤頁)。
    }
    return null;
  }
}

final googleDriveClientProvider = Provider<GoogleDriveClient>((ref) {
  final account = ref.watch(googleDriveAccountProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  return GoogleDriveClient(
    client,
    authHeaders: account.authHeaders,
    clearAuthCache: account.clearAuthCache,
  );
});
