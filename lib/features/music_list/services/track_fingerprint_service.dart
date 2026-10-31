import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/features/music_list/models/track_fingerprint_entity.dart';

/// 計算曲目的內容指紋(track id):`sha1(檔案大小 + 頭 64KB + 尾 64KB)`。
///
/// 只取頭尾而非整檔:大音樂庫整檔 hash 太慢;頭尾包含 tag 與音訊資料,
/// 加上檔案大小實務上足以區分不同曲目,且跨裝置 / 重灌後對同一檔案穩定。
/// 結果以 (size, mtime) 為條件快取於 Isar,檔案沒變不重讀內容;
/// 需要重算的檔案整批在背景 isolate 讀檔 + hash,不佔 main isolate 幀預算。
class TrackFingerprintService {
  TrackFingerprintService(this._isar);

  static const _chunkSize = 64 * 1024;

  final Isar _isar;

  IsarCollection<TrackFingerprintEntity> get _col =>
      _isar.trackFingerprintEntitys;

  /// 反查指紋對應的快取路徑(同內容存在多份檔案時全部回傳,
  /// 由呼叫端挑仍存在者)。
  List<String> cachedPathsForHash(String hash) => [
    for (final entity in _col.filter().hashEqualTo(hash).findAllSync())
      entity.path,
  ];

  /// 回傳 `路徑 -> 指紋`;讀不到的檔案不在結果中(由呼叫端 fallback)。
  Future<Map<String, String>> fingerprints(Iterable<String> paths) async {
    final result = <String, String>{};
    final pending = <({String path, int size, int modifiedMs})>[];
    for (final path in paths) {
      try {
        final stat = await File(path).stat();
        final modifiedMs = stat.modified.millisecondsSinceEpoch;
        final cached = _col.getByPathSync(path);
        if (cached != null &&
            cached.sizeBytes == stat.size &&
            cached.modifiedMs == modifiedMs) {
          result[path] = cached.hash;
          continue;
        }
        pending.add((path: path, size: stat.size, modifiedMs: modifiedMs));
      } catch (_) {
        // stat 失敗(權限 / 檔案消失等):跳過,呼叫端退回 MediaStore id。
      }
    }
    if (pending.isEmpty) return result;

    final hashes = await _computeHashesInIsolate(pending);

    final updates = <TrackFingerprintEntity>[];
    for (final job in pending) {
      final hash = hashes[job.path];
      if (hash == null) continue; // isolate 內讀檔失敗:同 stat 失敗處理。
      result[job.path] = hash;
      // path 為 unique replace 索引,直接 put 新實體即覆蓋舊快取列。
      updates.add(
        TrackFingerprintEntity()
          ..path = job.path
          ..sizeBytes = job.size
          ..modifiedMs = job.modifiedMs
          ..hash = hash,
      );
    }
    if (updates.isNotEmpty) {
      await _isar.writeTxn(() => _col.putAll(updates));
    }
    return result;
  }

  /// 計算單一檔案指紋但不寫入快取;給選檔器產生的暫存複本用,
  /// 避免暫存路徑殘留在快取表。讀不到回 null。
  static Future<String?> fingerprintUncached(String path) async {
    try {
      final size = await File(path).length();
      return await Isolate.run(() => _hashFile(path, size));
    } catch (_) {
      return null;
    }
  }

  /// 把 hash 計算送進獨立 isolate,不佔 main isolate 幀預算。
  ///
  /// 必須包在 static 方法內建立 closure:instance method 內的 closure
  /// 會連同 method context 捕捉 `this`,`_isar`(native 物件)不可跨
  /// isolate 傳送,`Isolate.spawn` 會直接丟例外。
  static Future<Map<String, String>> _computeHashesInIsolate(
    List<({String path, int size, int modifiedMs})> jobs,
  ) => Isolate.run(() => _computeHashes(jobs));

  /// 於背景 isolate 執行:整批讀檔 + sha1。讀不到的檔案不在結果中。
  static Future<Map<String, String>> _computeHashes(
    List<({String path, int size, int modifiedMs})> jobs,
  ) async {
    final result = <String, String>{};
    for (final job in jobs) {
      try {
        result[job.path] = await _hashFile(job.path, job.size);
      } catch (_) {
        // 讀檔失敗:跳過。
      }
    }
    return result;
  }

  static Future<String> _hashFile(String path, int size) async {
    final file = await File(path).open();
    try {
      // chunked conversion 直接餵 bytes,避免 spread 進 List<int> 的
      // boxing 複製。
      Digest? digest;
      final input = sha1.startChunkedConversion(
        ChunkedConversionSink<Digest>.withCallback((d) => digest = d.single),
      );
      input.add('$size:'.codeUnits);
      input.add(await file.read(_chunkSize));
      // 檔案大於兩個 chunk 才另取尾段,避免與頭段重疊重複計算。
      if (size > _chunkSize * 2) {
        await file.setPosition(size - _chunkSize);
        input.add(await file.read(_chunkSize));
      }
      input.close();
      return digest!.toString();
    } finally {
      await file.close();
    }
  }
}

final trackFingerprintServiceProvider = Provider<TrackFingerprintService>(
  (ref) => TrackFingerprintService(ref.watch(isarProvider)),
);
