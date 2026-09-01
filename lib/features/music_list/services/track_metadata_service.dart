import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/features/music_list/models/track_metadata_entity.dart';

/// 以 ffprobe 讀取本機音訊檔的 tag 中繼資料(title/artist/album/duration),
/// 供沒有 MediaStore 的平台(iOS 的 DocumentsMusicSource)建 Track 用。
///
/// ffprobe 逐檔執行不便宜,結果以 (size, mtime) 為條件快取於 Isar,
/// 檔案沒變不重讀(與 TrackFingerprintService 同一套快取策略)。
class TrackMetadataService {
  TrackMetadataService(this._isar);

  final Isar _isar;

  IsarCollection<TrackMetadataEntity> get _col => _isar.trackMetadataEntitys;

  /// 回傳 `路徑 -> 中繼資料`;stat 失敗的檔案不在結果中,
  /// 讀不到 tag 的檔案仍有 entry(欄位為 null)。
  Future<Map<String, TrackMetadataEntity>> metadataFor(
    Iterable<String> paths,
  ) async {
    final result = <String, TrackMetadataEntity>{};
    final updates = <TrackMetadataEntity>[];
    for (final path in paths) {
      try {
        final stat = await File(path).stat();
        final modifiedMs = stat.modified.millisecondsSinceEpoch;
        final cached = _col.getByPathSync(path);
        if (cached != null &&
            cached.sizeBytes == stat.size &&
            cached.modifiedMs == modifiedMs) {
          result[path] = cached;
          continue;
        }
        final probed = await _probe(path)
          ..sizeBytes = stat.size
          ..modifiedMs = modifiedMs;
        result[path] = probed;
        updates.add(probed);
      } catch (_) {
        // stat 失敗(檔案消失等):跳過,呼叫端以檔名顯示。
      }
    }
    if (updates.isNotEmpty) {
      await _isar.writeTxn(() => _col.putAll(updates));
    }
    return result;
  }

  Future<TrackMetadataEntity> _probe(String path) async {
    final entity = TrackMetadataEntity()..path = path;
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) return entity; // 非音訊/損壞檔:tag 全 null。

    // tag key 大小寫依容器格式而異(ID3 v.s. MP4 atom),統一小寫比對。
    final tags = {
      for (final e in (info.getTags() ?? const {}).entries)
        e.key.toString().toLowerCase(): e.value?.toString(),
    };
    return entity
      ..title = _nonEmpty(tags['title'])
      ..artist = _nonEmpty(tags['artist'])
      ..album = _nonEmpty(tags['album'])
      ..durationMs = _durationToMs(info.getDuration());
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// ffprobe 的 duration 是秒數字串(例 "215.379000")。
  static int? _durationToMs(String? seconds) {
    final parsed = double.tryParse(seconds ?? '');
    return parsed == null ? null : (parsed * 1000).round();
  }
}

final trackMetadataServiceProvider = Provider<TrackMetadataService>(
  (ref) => TrackMetadataService(ref.watch(isarProvider)),
);
