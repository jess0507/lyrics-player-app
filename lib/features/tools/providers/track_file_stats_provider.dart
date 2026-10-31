import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/music_list/providers/music_library.dart';
import 'package:seek_player/features/tools/models/track_file_stat.dart';

/// 曲庫中每首曲目的檔案 stat(`filePath -> TrackFileStat`);
/// stat 失敗的檔案不在結果中。曲庫重掃後自動重算。
final trackFileStatsProvider = FutureProvider<Map<String, TrackFileStat>>((
  ref,
) async {
  final tracks = ref.watch(musicLibraryProvider).valueOrNull ?? const [];
  final entries = await Future.wait([
    for (final track in tracks)
      File(track.filePath)
          .stat()
          .then<MapEntry<String, TrackFileStat>?>(
            (stat) => stat.type == FileSystemEntityType.notFound
                ? null
                : MapEntry(
                    track.filePath,
                    TrackFileStat(
                      sizeBytes: stat.size,
                      modified: stat.modified,
                    ),
                  ),
          )
          .catchError((_) => null),
  ]);
  return Map.fromEntries(entries.nonNulls);
});
