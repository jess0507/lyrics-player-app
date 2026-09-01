import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/music_list/services/music_library_source.dart';
import 'package:seek_player/features/music_list/services/track_fingerprint_service.dart';
import 'package:seek_player/features/music_list/services/track_metadata_service.dart';

/// iOS 音樂庫來源:掃描 app 自家 Documents 目錄(方案 A,
/// 見 plans/23-ios-support.md)。
///
/// 使用者透過「匯入音樂」(MusicImportService)或「檔案」app
/// (Info.plist 已開 UIFileSharingEnabled)把音訊檔放進 Documents;
/// 掃自家沙盒不需任何系統權限。檔案路徑真實可讀,內容指紋 trackId、
/// 歌詞 AI、ffmpeg 壓縮、分享等下游功能與 Android 走同一條路。
class DocumentsMusicSource implements MusicLibrarySource {
  DocumentsMusicSource(this._ref);

  final Ref _ref;

  /// 限 AVPlayer(just_audio iOS 後端)播得動的格式;ogg/opus/wma 不支援。
  static const supportedExtensions = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'flac',
    'aiff',
    'aif',
    'caf',
  };

  /// Documents 下 app 自建的非音樂目錄(自訂封面),掃描時跳過。
  /// Isar 資料庫檔副檔名不在 [supportedExtensions],自然被濾掉。
  static const _excludedDirNames = {'covers'};

  @override
  Future<List<Track>> scan() async {
    final paths = await audioFilePaths();
    final fingerprints = await _ref
        .read(trackFingerprintServiceProvider)
        .fingerprints(paths);
    final metadata = await _ref
        .read(trackMetadataServiceProvider)
        .metadataFor(paths);

    final tracks = [
      for (final path in paths)
        Track(
          // 指紋算不出來(理論上僅剛好被刪的檔案)退回路徑本身,
          // 與 pathForFallbackId 的約定對應。
          id: fingerprints[path] ?? path,
          uri: Uri.file(path).toString(),
          filePath: path,
          title: metadata[path]?.title ?? _fileNameWithoutExtension(path),
          artist: metadata[path]?.artist,
          album: metadata[path]?.album,
          durationMs: metadata[path]?.durationMs,
        ),
    ];
    // 與 Android 的 MediaStore 查詢一致:標題排序、不分大小寫。
    tracks.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return tracks;
  }

  @override
  Future<List<String>> audioFilePaths() async {
    final docs = await getApplicationDocumentsDirectory();
    final paths = <String>[];
    await for (final entity in docs.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = entity.path.substring(docs.path.length + 1);
      final segments = relative.split('/');
      if (_excludedDirNames.contains(segments.first)) continue;
      final name = segments.last;
      if (name.startsWith('.')) continue;
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      if (!supportedExtensions.contains(name.substring(dot + 1).toLowerCase())) {
        continue;
      }
      paths.add(entity.path);
    }
    paths.sort();
    return paths;
  }

  @override
  Future<String?> pathForFallbackId(String trackId) async {
    // iOS 的 fallback id 即檔案路徑本身(見 scan)。
    if (!trackId.startsWith('/')) return null;
    return File(trackId).existsSync() ? trackId : null;
  }

  static String _fileNameWithoutExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
