import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/services/content_path_resolver.dart';
import 'package:seek_player/features/music_list/services/music_import_service.dart';
import 'package:seek_player/features/music_list/services/track_hash_service.dart';
import 'package:seek_player/features/music_list/services/track_registrar.dart';

/// 選檔比對結果。
sealed class TrackFileMatch {
  const TrackFileMatch();
}

/// 使用者取消選檔。
class TrackFileCancelled extends TrackFileMatch {
  const TrackFileCancelled();
}

/// 對應到的 [track](曲庫曲目或新登記的 TrackEntity);[imported] 為 true
/// 表示原本不在曲庫、剛匯入。
class TrackFileFound extends TrackFileMatch {
  const TrackFileFound(this.track, {this.imported = false});

  final Track track;
  final bool imported;
}

/// 不在曲庫中,且匯入失敗(或匯入後重掃仍找不到)。
class TrackFileImportFailed extends TrackFileMatch {
  const TrackFileImportFailed();
}

/// 工具選曲頁的「從檔案選擇」:以系統選檔器挑音訊檔,再對回曲庫中的 [Track]。
///
/// 選檔器回傳的 `path` 是複製到 app 暫存目錄的副本,和曲庫路徑
/// 永遠對不上,所以改用 [PlatformFile.identifier](原始檔的 content URI)
/// 交給 [ContentPathResolver] 還原實體路徑,再以 trackId 比對:
/// 1. trackId 在曲庫中 → 直接用;
/// 2. 有實體路徑但不在曲庫 → 建立新的 TrackEntity([TrackRegistrar]);
/// 3. 還原不出實體路徑 → 以 [MusicImportService.importFile] 匯入音樂庫、
///    重掃後再比對一次。
class TrackFileMatcher {
  const TrackFileMatcher(this._ref);

  final Ref _ref;

  Future<TrackFileMatch> pickAndMatch() async {
    final picked = (await FilePicker.pickFiles(
      type: FileType.audio,
    ))?.files.singleOrNull;
    final path = picked?.path;
    if (picked == null || path == null) return const TrackFileCancelled();

    try {
      final realPath = await ContentPathResolver.resolve(
        picked.identifier ?? '',
      );
      if (realPath != null) {
        final existing = await _findByFile(realPath);
        if (existing != null) return TrackFileFound(existing);
        final registered = await _ref
            .read(trackRegistrarProvider)
            .register(path: realPath);
        if (registered != null) return TrackFileFound(registered);
      }

      final importedPath = await _ref
          .read(musicImportServiceProvider)
          .importFile(path, picked.name);
      if (importedPath == null) return const TrackFileImportFailed();

      await _ref.read(musicLibraryProvider.notifier).refresh();
      final imported = await _findByFile(importedPath);
      return imported == null
          ? const TrackFileImportFailed()
          : TrackFileFound(imported, imported: true);
    } finally {
      // 比對 / 匯入完即清掉選檔器的暫存複本;失敗不影響結果。
      await FilePicker.clearTemporaryFiles().catchError((_) => null);
    }
  }

  /// 以內容比對曲庫:算 [path] 的 trackId,找同 trackId 的曲目。
  Future<Track?> _findByFile(String path) async {
    final trackId = await _ref.read(trackHashServiceProvider).trackIdOf(path);
    if (trackId == null) return null;
    final tracks = _ref.read(musicLibraryProvider).valueOrNull ?? const [];
    for (final t in tracks) {
      if (t.trackId == trackId) return t;
    }
    return null;
  }
}

final trackFileMatcherProvider = Provider<TrackFileMatcher>(
  (ref) => TrackFileMatcher(ref),
);
