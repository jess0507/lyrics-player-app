import 'dart:io';

import 'package:flutter/services.dart';

import 'package:seek_player/core/crash_reporter.dart';

/// 把 content URI 還原成實體檔案路徑(不複製檔案),原生端見
/// `ExternalOpenChannel.kt` 的 `resolvePath`(MediaStore `_data`、
/// DocumentsProvider 的 `audio:` / `raw:` / `msf:`、DISPLAY_NAME + SIZE 反查)。
abstract final class ContentPathResolver {
  static const _channel = MethodChannel('seek_player/external_open');

  /// 還原 [uri] 的實體路徑;還原不出或檔案不存在回 null。
  static Future<String?> resolve(String uri) async {
    if (uri.isEmpty) return null;
    try {
      final path = await _channel.invokeMethod<String>('resolvePath', {
        'uri': uri,
      });
      if (path == null || path.isEmpty) return null;
      return File(path).existsSync() ? path : null;
    } catch (e, s) {
      reportError(e, s, reason: 'ContentPathResolver 還原路徑失敗');
      return null;
    }
  }
}
