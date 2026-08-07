import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/lyrics/services/lyrics_parser.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 匯入失敗原因,供 UI 映射到對應的 l10n 失敗訊息。
enum LyricsImportError { tooLarge, unreadable, empty }

/// 匯入失敗;UI 以 [error] 決定 toast 文案。使用者取消選檔不是失敗,
/// 由 [LyricsImportService.importForTrack] 回 false 表示。
class LyricsImportException implements Exception {
  const LyricsImportException(this.error, {this.message});

  final LyricsImportError error;

  /// 供錯誤回報用的細節(檔案大小 / 格式等),不是 UI 文案。
  final String? message;

  @override
  String toString() =>
      'LyricsImportException(${error.name}'
      '${message == null ? '' : ', $message'})';
}

/// 手動匯入歌詞:SAF 選檔 → 大小上限 → 解碼 → 試 parse 驗證 → 存 Isar。
/// 入口由顯示計畫提供(播放頁歌詞視圖的空狀態按鈕)。
class LyricsImportService {
  LyricsImportService(this._ref);

  final Ref _ref;

  /// 內容上限約 1MB,超過拒收。
  static const _maxBytes = 1024 * 1024;

  /// 為 [trackId] 匯入歌詞。回傳 true 表示已存檔;false 表示使用者取消選檔。
  /// 失敗(過大 / 無法解碼 / 解析後無內容)拋 [LyricsImportException]。
  Future<bool> importForTrack({
    required String trackId,
    required String title,
  }) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['lrc', 'txt', 'srt', 'vtt'],
    );
    final file = picked?.files.singleOrNull;
    if (file == null || file.path == null) return false; // 取消

    if (file.size > _maxBytes) {
      throw LyricsImportException(
        LyricsImportError.tooLarge,
        message:
            'size=${file.size}B > max=${_maxBytes}B, ext=${file.extension}',
      );
    }

    final bytes = await File(file.path!).readAsBytes();
    final content = _decode(bytes);
    final format = detectLyricsFormat(file.name);
    if (parseLyrics(content, format).isEmpty) {
      throw LyricsImportException(
        LyricsImportError.empty,
        message: 'format=${format.name}, chars=${content.length}',
      );
    }

    final entity = LyricsEntity()
      ..trackId = trackId
      ..title = title
      ..format = format
      ..source = LyricsSource.manual
      ..content = content
      ..addedAt = DateTime.now();
    await _ref.read(lyricsRepositoryProvider).save(entity);
    _ref.invalidate(trackLyricsProvider(trackId));
    return true;
  }

  /// UTF-8 為主(剝除 BOM);嚴格解碼失敗時退回 allowMalformed,接受少量
  /// 亂碼並列為已知限制(GBK / Big5 等歷史編碼留待實際遇到再引入轉碼)。
  String _decode(List<int> bytes) {
    final body = _stripBom(bytes);
    try {
      return utf8.decode(body);
    } on FormatException {
      return utf8.decode(body, allowMalformed: true);
    }
  }

  List<int> _stripBom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return bytes.sublist(3);
    }
    return bytes;
  }
}

final lyricsImportServiceProvider = Provider<LyricsImportService>(
  (ref) => LyricsImportService(ref),
);
