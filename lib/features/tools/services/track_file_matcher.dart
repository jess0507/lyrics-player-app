import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/music_list/services/music_import_service.dart';
import 'package:seek_player/features/music_list/services/track_fingerprint_service.dart';

/// 選檔比對結果。
sealed class TrackFileMatch {
  const TrackFileMatch();
}

/// 使用者取消選檔。
class TrackFileCancelled extends TrackFileMatch {
  const TrackFileCancelled();
}

/// 對應到曲庫中的 [track];[imported] 為 true 表示原本不在曲庫、剛匯入。
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
/// 先比對實際路徑(iOS / 選檔器回傳原檔時命中);Android 選檔器多半複製到
/// 暫存目錄,路徑對不上,改以內容指紋比對 track id(見 TrackFingerprintService)。
/// 都對不上就以 [MusicImportService.importFile] 匯入音樂庫、重掃後再比對一次。
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
      final hash = await TrackFingerprintService.fingerprintUncached(path);
      final existing = _find(_tracks(), path: path, hash: hash);
      if (existing != null) return TrackFileFound(existing);

      final importedPath = await _ref
          .read(musicImportServiceProvider)
          .importFile(path, picked.name);
      if (importedPath == null) return const TrackFileImportFailed();

      await _ref.read(musicLibraryProvider.notifier).refresh();
      final imported = _find(_tracks(), path: importedPath, hash: hash);
      return imported == null
          ? const TrackFileImportFailed()
          : TrackFileFound(imported, imported: true);
    } finally {
      // 比對 / 匯入完即清掉選檔器的暫存複本;失敗不影響結果。
      await FilePicker.clearTemporaryFiles().catchError((_) => null);
    }
  }

  List<Track> _tracks() =>
      _ref.read(musicLibraryProvider).valueOrNull ?? const [];

  static Track? _find(
    List<Track> tracks, {
    required String path,
    required String? hash,
  }) {
    for (final t in tracks) {
      if (t.filePath == path) return t;
    }
    if (hash == null) return null;
    for (final t in tracks) {
      if (t.id == hash) return t;
    }
    return null;
  }
}

final trackFileMatcherProvider = Provider<TrackFileMatcher>(
  (ref) => TrackFileMatcher(ref),
);
