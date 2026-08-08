import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:seek_player/features/lyrics/online/models/lrclib_result.dart';

/// search 回應每筆候選都內含完整 plain / synced 歌詞全文,整包可達數百 KB;
/// 在背景 isolate 解析,避免 jsonDecode 卡住 UI thread 一整個 frame。
List<LrclibResult> _parseSearchResults(String body) {
  final list = jsonDecode(body) as List<dynamic>;
  return list
      .map((e) => LrclibResult.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// LRCLIB 查詢失敗(逾時 / 網路錯誤 / 非預期狀態碼)。查無結果不算失敗,
/// 由呼叫端以空 list / null 判斷。
class LrclibException implements Exception {
  const LrclibException(this.message);

  final String message;

  @override
  String toString() => 'LrclibException($message)';
}

/// 純函式包裝 LRCLIB(https://lrclib.net/docs)HTTP 呼叫,不持有查詢狀態。
class LrclibClient {
  LrclibClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _baseUrl = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 10);

  /// 精確查詢(`GET /api/get`):title/artist/album/duration 需完全相符,
  /// 查無結果回 null(LRCLIB 回 404,非例外)。
  Future<LrclibResult?> get({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    final uri = Uri.parse('$_baseUrl/get').replace(
      queryParameters: {
        'track_name': trackName,
        'artist_name': artistName,
        if (albumName != null && albumName.isNotEmpty)
          'album_name': albumName,
        if (durationSeconds != null) 'duration': '$durationSeconds',
      },
    );
    final response = await _send(uri);
    if (response.statusCode == 404) return null;
    _checkStatus(response);
    return LrclibResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 模糊查詢(`GET /api/search`):以曲名為主,回傳多筆候選(可能為空)。
  Future<List<LrclibResult>> search({
    required String trackName,
    String? artistName,
    String? albumName,
  }) {
    return _search({
      'track_name': trackName,
      if (artistName != null && artistName.isNotEmpty)
        'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
    });
  }

  /// 關鍵字模糊查詢(`GET /api/search?q=`):不限欄位比對,
  /// 供使用者自行編輯查詢字串重查時使用。
  Future<List<LrclibResult>> searchByKeyword(String keyword) {
    return _search({'q': keyword});
  }

  Future<List<LrclibResult>> _search(Map<String, String> queryParameters) async {
    final uri = Uri.parse(
      '$_baseUrl/search',
    ).replace(queryParameters: queryParameters);
    final response = await _send(uri);
    _checkStatus(response);
    return compute(_parseSearchResults, response.body);
  }

  Future<http.Response> _send(Uri uri) async {
    try {
      return await _http.get(uri).timeout(_timeout);
    } on Exception catch (e) {
      throw LrclibException('network error: $e');
    }
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode != 200) {
      throw LrclibException('unexpected status ${response.statusCode}');
    }
  }
}
