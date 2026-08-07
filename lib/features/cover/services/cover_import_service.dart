import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seek_player/features/cover/models/track_cover_entity.dart';
import 'package:seek_player/features/cover/providers/track_cover_color_provider.dart';
import 'package:seek_player/features/cover/providers/track_cover_provider.dart';
import 'package:seek_player/features/cover/services/cover_color.dart';
import 'package:seek_player/features/cover/services/track_cover_repository.dart';

/// 設定封面失敗原因,供 UI 映射到對應的 l10n 失敗訊息。
enum CoverImportError { tooLarge, unreadable }

/// 設定封面失敗;UI 以 [error] 決定 toast 文案。使用者取消選圖不是失敗,
/// 由 [CoverImportService.pickAndSetForTrack] 回 false 表示。
class CoverImportException implements Exception {
  const CoverImportException(this.error, {this.message});

  final CoverImportError error;

  /// 供錯誤回報用的細節(檔案大小 / 副檔名等),不是 UI 文案。
  final String? message;

  @override
  String toString() =>
      'CoverImportException(${error.name}'
      '${message == null ? '' : ', $message'})';
}

/// 自訂封面:挑圖 → 複製到 app 文件夾 `covers/` → upsert(唯一索引 replace)。
/// 「新增」與「更換」共用本路徑,差別只在動作前先刪掉舊圖檔(避免孤兒檔)。
class CoverImportService {
  CoverImportService(this._ref);

  final Ref _ref;

  /// 圖檔大小上限約 10MB,超過拒收。
  static const _maxBytes = 10 * 1024 * 1024;

  /// 為 [trackId] 挑一張封面並設定。回傳 true 表示已設定;false 表示使用者
  /// 取消選圖。失敗(過大 / 無法讀取)拋 [CoverImportException]。
  Future<bool> pickAndSetForTrack(String trackId) async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final file = picked?.files.singleOrNull;
    if (file == null || file.path == null) return false; // 取消

    if (file.size > _maxBytes) {
      throw CoverImportException(
        CoverImportError.tooLarge,
        message:
            'size=${file.size}B > max=${_maxBytes}B, '
            'ext=${_extension(file.name)}',
      );
    }

    final source = File(file.path!);
    final bytes = await _read(source);

    final dir = await _coversDir();
    final ext = _extension(file.name);
    final dest = File(
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await dest.writeAsBytes(bytes, flush: true);

    final repo = _ref.read(trackCoverRepositoryProvider);
    await _deleteOldFile(repo.findByTrackId(trackId)?.imagePath);

    // 設定當下即算好主色並一併存入,讓播放頁切到本曲時可直接取用。
    final color = await extractCoverColor(dest);
    final entity = TrackCoverEntity()
      ..trackId = trackId
      ..imagePath = dest.path
      ..colorValue = color?.toARGB32()
      ..addedAt = DateTime.now();
    await repo.save(entity);
    _ref.invalidate(trackCoverProvider(trackId));
    _ref.invalidate(trackCoverColorProvider(trackId));
    return true;
  }

  /// 移除 [trackId] 的自訂封面(刪圖檔 + 紀錄)。
  Future<void> removeForTrack(String trackId) async {
    final repo = _ref.read(trackCoverRepositoryProvider);
    await _deleteOldFile(repo.findByTrackId(trackId)?.imagePath);
    await repo.deleteByTrackId(trackId);
    _ref.invalidate(trackCoverProvider(trackId));
    _ref.invalidate(trackCoverColorProvider(trackId));
  }

  /// 為既有封面中尚未快取主色者背景補算並寫回,避免之後切歌時才即時解析
  /// 造成卡頓。載入音樂後 fire-and-forget 呼叫;best-effort,單張失敗略過。
  Future<void> backfillMissingColors() async {
    final repo = _ref.read(trackCoverRepositoryProvider);
    for (final entity in repo.findMissingColor()) {
      final file = File(entity.imagePath);
      if (!file.existsSync()) continue;
      final color = await extractCoverColor(file);
      if (color == null) continue;
      entity.colorValue = color.toARGB32();
      await repo.save(entity);
      _ref.invalidate(trackCoverColorProvider(entity.trackId));
    }
  }

  Future<List<int>> _read(File source) async {
    try {
      return await source.readAsBytes();
    } on FileSystemException catch (e) {
      throw CoverImportException(CoverImportError.unreadable, message: '$e');
    }
  }

  Future<Directory> _coversDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/covers');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// 取副檔名(含 `.`,小寫);無副檔名回 `.img`。
  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.img';
    return name.substring(dot).toLowerCase();
  }

  /// 刪除舊封面圖檔;路徑為空或檔案已不在皆靜默略過。
  Future<void> _deleteOldFile(String? path) async {
    if (path == null) return;
    final old = File(path);
    if (old.existsSync()) await old.delete();
  }
}

final coverImportServiceProvider = Provider<CoverImportService>(
  (ref) => CoverImportService(ref),
);
