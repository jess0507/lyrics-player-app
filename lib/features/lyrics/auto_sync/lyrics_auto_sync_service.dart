import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crash_reporter.dart';
import '../models/lyrics_entity.dart';
import '../services/lyrics_parser.dart';
import '../services/lyrics_repository.dart';
import '../services/track_audio_resolver.dart';
import '../providers/track_lyrics_provider.dart';
import 'audio_compressor.dart';

/// 必須與 Cloud Functions 部署的 region(`functions/main.py` 的 `_REGION`)一致。
const _functionsRegion = 'asia-east1';

/// 對時流程的階段,供進度 UI 顯示。
enum LyricsAutoSyncStep { compressing, uploading, aligning }

/// 對齊引擎:對應後端不同的 Cloud Run 服務(`align_lyrics` 依此路由)。
/// - [aeneas]:`aeneas_service`,輕量、句級對齊。
/// - [whisperx]:`whisperx_service`,wav2vec2 字級對齊,中文 / 歌聲一般較佳。
enum LyricsAlignEngine {
  aeneas,
  whisperx;

  /// 送給後端 callable 的引擎識別碼。
  String get wireName => name;
}

/// 對時失敗原因,UI 據此映射 l10n 訊息並決定提示語氣。
enum LyricsAutoSyncError {
  /// 未登入(callable 需身分)。
  notLoggedIn,

  /// 找不到可讀的音訊檔(來源被刪 / scoped storage 無法存取)。
  noAudio,

  /// 該曲沒有歌詞 / 歌詞為空——對時是「補時間」,需先有純文字歌詞。
  noLyrics,

  /// 本機壓縮音訊失敗。
  compressFailed,

  /// 上傳 GCS 失敗。
  uploadFailed,

  /// 超過每日對時次數上限。
  rateLimited,

  /// 後端對齊失敗(片段不符 / 信心過低);應保留原 unsynced 文字。
  alignmentFailed,

  /// 連線 / 服務暫時不可用。
  network,

  /// 已有其他背景歌詞任務執行中(背景一次只跑一件)。
  busy,

  /// 其他未預期錯誤。
  unknown,
}

class LyricsAutoSyncException implements Exception {
  const LyricsAutoSyncException(this.error);

  final LyricsAutoSyncError error;
}

/// 歌詞自動對時:讀本機音訊 → 壓縮 → 上傳 GCS → 呼叫 `align_lyrics` callable
/// (後端轉呼 aeneas)→ 把回傳的同步 LRC 寫回同一 [LyricsEntity]
/// (`source = generated`、`format = lrc`),顯示端自動切到同步視圖。
///
/// 失敗一律不寫半套時間:對齊失敗 / 任一步出錯時保留原本的純文字歌詞。
class LyricsAutoSyncService {
  LyricsAutoSyncService(this._ref);

  final Ref _ref;

  /// 為 [trackId] 執行對時。[language] 為語言提示(BCP-47,後端正規化)。
  /// [engine] 指定後端對齊引擎(aeneas / WhisperX)。
  /// 各階段以 [onStep] 回報進度。失敗拋 [LyricsAutoSyncException]。
  Future<void> autoSync({
    required String trackId,
    required String title,
    required String language,
    required LyricsAlignEngine engine,
    void Function(LyricsAutoSyncStep step)? onStep,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const LyricsAutoSyncException(LyricsAutoSyncError.notLoggedIn);
    }

    final repo = _ref.read(lyricsRepositoryProvider);
    final entity = repo.findByTrackId(trackId);
    if (entity == null) {
      throw const LyricsAutoSyncException(LyricsAutoSyncError.noLyrics);
    }
    // 取非空白行送對齊(與後端「再濾掉空行」一一對應)。
    final lines = [
      for (final line in parseLyrics(entity.content, entity.format).lines)
        if (line.text.trim().isNotEmpty) line.text.trim(),
    ];
    if (lines.isEmpty) {
      throw const LyricsAutoSyncException(LyricsAutoSyncError.noLyrics);
    }

    final audioPath = await _ref
        .read(trackAudioResolverProvider)
        .resolve(trackId);
    if (audioPath == null) {
      throw const LyricsAutoSyncException(LyricsAutoSyncError.noAudio);
    }

    onStep?.call(LyricsAutoSyncStep.compressing);
    final File compressed;
    try {
      compressed = await _ref
          .read(audioCompressorProvider)
          .compressForAlignment(audioPath);
    } on AudioCompressException catch (e, s) {
      reportError(e, s, reason: '歌詞對時：壓縮音訊失敗');
      throw const LyricsAutoSyncException(LyricsAutoSyncError.compressFailed);
    }

    onStep?.call(LyricsAutoSyncStep.uploading);
    final Reference storageRef;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      storageRef = FirebaseStorage.instance.ref(
        'align/${user.uid}/$trackId-$ts.m4a',
      );
      await storageRef.putFile(
        compressed,
        SettableMetadata(contentType: 'audio/mp4'),
      );
    } on FirebaseException catch (e, s) {
      reportError(e, s, reason: '歌詞對時：上傳音訊到 GCS 失敗');
      throw const LyricsAutoSyncException(LyricsAutoSyncError.uploadFailed);
    } finally {
      // 壓縮暫存檔已上傳(或上傳失敗),本機不再需要。
      unawaited(compressed.delete().catchError((_) => compressed));
    }

    onStep?.call(LyricsAutoSyncStep.aligning);
    final String lrc;
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: _functionsRegion,
      ).httpsCallable(
        'align_lyrics',
        // client 預設逾時僅 70s,但 CPU 對齊整首歌常破 1–2 分鐘(後端
        // timeout_sec=600)。不放寬會在後端跑完前就 deadline-exceeded →
        // 被映成 network「連線錯誤」。對齊後端逾時設為 10 分鐘。
        options: HttpsCallableOptions(timeout: const Duration(minutes: 10)),
      );
      final result = await callable.call<Object?>({
        'lines': lines,
        'bucket': storageRef.bucket,
        'object': storageRef.fullPath,
        'language': language,
        'format': 'm4a',
        'engine': engine.wireName,
      });
      // 不同平台回傳 Map 的鍵型別不一,故動態取值。
      final data = result.data;
      final value = data is Map ? data['lrc'] : null;
      if (value is! String || value.isEmpty) {
        // 後端回 200 卻取不到 lrc:記下回應形狀(不含歌詞內容),
        // 以區分平台通道反序列化問題與後端真的沒給。
        reportError(
          StateError(
            'align_lyrics 回應缺 lrc：data=${data.runtimeType}'
            '${data is Map ? ' keys=${data.keys.toList()}' : ''}'
            ' lrc=${value is String ? 'String(len=${value.length})' : value.runtimeType}',
          ),
          StackTrace.current,
          reason: 'align_lyrics 回應解析失敗',
        );
        throw const LyricsAutoSyncException(
          LyricsAutoSyncError.alignmentFailed,
        );
      }
      lrc = value;
    } on FirebaseFunctionsException catch (e, s) {
      // code/message 是判別故障層的關鍵:failed-precondition / internal 為
      // Function / 後端問題;unavailable 無 message 多為連線層死亡。
      debugPrint('Firebase Function align_lyrics: $e');
      // 唯一上報點(背景 runner 端不再重複報)。未登入 / 配額滿屬
      // 使用者狀態非 bug,不上報。
      if (e.code != 'unauthenticated' && e.code != 'resource-exhausted') {
        reportError(e, s, reason: 'align_lyrics 失敗（code=${e.code}）');
      }
      throw LyricsAutoSyncException(_mapFunctionsError(e));
    }

    // 沿用唯一索引 replace 覆蓋原歌詞;來源 / 格式改為對時產物。
    final synced = LyricsEntity()
      ..trackId = trackId
      ..title = title
      ..format = LyricsFormat.lrc
      ..source = LyricsSource.generated
      ..content = lrc
      ..addedAt = DateTime.now();
    await repo.save(synced);
    _ref.invalidate(trackLyricsProvider(trackId));
  }

  LyricsAutoSyncError _mapFunctionsError(FirebaseFunctionsException e) =>
      switch (e.code) {
        'unauthenticated' => LyricsAutoSyncError.notLoggedIn,
        'resource-exhausted' => LyricsAutoSyncError.rateLimited,
        'failed-precondition' => LyricsAutoSyncError.alignmentFailed,
        'unavailable' || 'deadline-exceeded' => LyricsAutoSyncError.network,
        _ => LyricsAutoSyncError.unknown,
      };
}

final lyricsAutoSyncServiceProvider = Provider<LyricsAutoSyncService>(
  (ref) => LyricsAutoSyncService(ref),
);
