import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 下載(匯出)歌詞:讀出儲存的原文,交給系統「另存檔案」對話框
/// (Android SAF / iOS Files)寫到使用者選擇的位置,副檔名依儲存格式。
class LyricsExportService {
  LyricsExportService(this._ref);

  final Ref _ref;

  /// 為 [trackId] 匯出歌詞檔,檔名以 [title] 為底。回傳 true 表示已存檔;
  /// false 表示使用者取消(查無歌詞極少見——選單僅在有歌詞時顯示——視同取消)。
  Future<bool> exportForTrack({
    required String trackId,
    required String title,
  }) async {
    final entity = _ref.read(lyricsRepositoryProvider).findByTrackId(trackId);
    if (entity == null) return false;

    final path = await FilePicker.saveFile(
      fileName: '${_sanitizeFileName(title)}.${entity.format.name}',
      type: FileType.custom,
      allowedExtensions: [entity.format.name],
      // Android / iOS 由 plugin 直接寫入 bytes,呼叫端不需再落地。
      bytes: Uint8List.fromList(utf8.encode(entity.content)),
    );
    return path != null;
  }

  /// 去除各平台檔名不合法字元;清完為空時退回固定名稱。
  String _sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'lyrics' : cleaned;
  }
}

final lyricsExportServiceProvider = Provider<LyricsExportService>(
  (ref) => LyricsExportService(ref),
);
