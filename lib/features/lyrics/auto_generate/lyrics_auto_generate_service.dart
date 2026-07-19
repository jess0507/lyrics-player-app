import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crash_reporter.dart';
import '../auto_sync/audio_compressor.dart';
import '../models/lyrics_entity.dart';
import '../providers/track_lyrics_provider.dart';
import '../services/lyrics_repository.dart';
import '../services/track_audio_resolver.dart';

/// 必須與 Cloud Functions 部署的 region(`functions/main.py` 的 `_REGION`)一致。
const _functionsRegion = 'asia-east1';

/// 自動產生歌詞流程的階段,供進度 UI 顯示。
enum LyricsAutoGenerateStep { compressing, uploading, transcribing }

/// 自動產生失敗原因,UI 據此映射 l10n 訊息並決定提示語氣。
enum LyricsAutoGenerateError {
  /// 未登入(callable 需身分)。
  notLoggedIn,

  /// 找不到可讀的音訊檔(來源被刪 / scoped storage 無法存取)。
  noAudio,

  /// 本機壓縮音訊失敗。
  compressFailed,

  /// 上傳 GCS 失敗。
  uploadFailed,

  /// 超過每日自動產生次數上限。
  rateLimited,

  /// 後端辨識不出可用歌詞;不寫入,保持無歌詞狀態。
  transcriptionFailed,

  /// 連線 / 服務暫時不可用。
  network,

  /// 已有其他背景歌詞任務執行中(背景一次只跑一件)。
  busy,

  /// 其他未預期錯誤。
  unknown,
}

class LyricsAutoGenerateException implements Exception {
  const LyricsAutoGenerateException(this.error);

  final LyricsAutoGenerateError error;
}

/// 歌詞自動產生:讀本機音訊 → 壓縮 → 上傳 GCS → 呼叫 `generate_lyrics` callable
/// (後端 WhisperX ASR 轉寫 + 對齊)→ 把回傳的同步 LRC 寫回 [LyricsEntity]
/// (`source = generated`、`format = lrc`),顯示端自動切到同步視圖。
///
/// 與對時(auto_sync)互補:對時是「已有純文字、只補時間」,本流程是「**沒有
/// 歌詞**、從音訊直接辨識」。語言交由後端自動偵測(不送 language)。
///
/// 失敗一律不寫入:辨識失敗 / 任一步出錯時保持原本的無歌詞狀態。
class LyricsAutoGenerateService {
  LyricsAutoGenerateService(this._ref);

  final Ref _ref;

  /// 為 [trackId] 執行自動產生。各階段以 [onStep] 回報進度。
  /// 失敗拋 [LyricsAutoGenerateException]。
  Future<void> generate({
    required String trackId,
    required String title,
    void Function(LyricsAutoGenerateStep step)? onStep,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const LyricsAutoGenerateException(
        LyricsAutoGenerateError.notLoggedIn,
      );
    }

    final audioPath = await _ref
        .read(trackAudioResolverProvider)
        .resolve(trackId);
    if (audioPath == null) {
      throw const LyricsAutoGenerateException(LyricsAutoGenerateError.noAudio);
    }

    onStep?.call(LyricsAutoGenerateStep.compressing);
    final File compressed;
    try {
      compressed = await _ref
          .read(audioCompressorProvider)
          .compressForAlignment(audioPath);
    } on AudioCompressException catch (e, s) {
      reportError(e, s, reason: '自動產生歌詞：壓縮音訊失敗');
      throw const LyricsAutoGenerateException(
        LyricsAutoGenerateError.compressFailed,
      );
    }

    onStep?.call(LyricsAutoGenerateStep.uploading);
    final Reference storageRef;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      storageRef = FirebaseStorage.instance.ref(
        'generate/${user.uid}/$trackId-$ts.m4a',
      );
      await storageRef.putFile(
        compressed,
        SettableMetadata(contentType: 'audio/mp4'),
      );
    } on FirebaseException catch (e, s) {
      reportError(e, s, reason: '自動產生歌詞：上傳音訊到 GCS 失敗');
      throw const LyricsAutoGenerateException(
        LyricsAutoGenerateError.uploadFailed,
      );
    } finally {
      // 壓縮暫存檔已上傳(或上傳失敗),本機不再需要。
      unawaited(compressed.delete().catchError((_) => compressed));
    }

    onStep?.call(LyricsAutoGenerateStep.transcribing);
    final String lrc;
    try {
      final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable(
            'generate_lyrics',
            // client 預設逾時僅 70s,但 CPU 轉寫整首歌常破 1–2 分鐘(後端
            // timeout_sec=600)。不放寬會在後端跑完前就 deadline-exceeded →
            // 被映成 network「連線錯誤」。對齊後端逾時設為 10 分鐘。
            options: HttpsCallableOptions(timeout: const Duration(minutes: 10)),
          );
      // 不送 language:交由後端自動偵測歌曲語言。
      final result = await callable.call<Object?>({
        'bucket': storageRef.bucket,
        'object': storageRef.fullPath,
        'format': 'm4a',
      });
      // 不同平台回傳 Map 的鍵型別不一,故動態取值。
      final data = result.data;
      final value = data is Map ? data['lrc'] : null;
      if (value is! String || value.isEmpty) {
        // 後端回 200 卻取不到 lrc:記下回應形狀(不含歌詞內容),
        // 以區分平台通道反序列化問題與後端真的沒給。
        reportError(
          StateError(
            'generate_lyrics 回應缺 lrc：data=${data.runtimeType}'
            '${data is Map ? ' keys=${data.keys.toList()}' : ''}'
            ' lrc=${value is String ? 'String(len=${value.length})' : value.runtimeType}',
          ),
          StackTrace.current,
          reason: 'generate_lyrics 回應解析失敗',
        );
        throw const LyricsAutoGenerateException(
          LyricsAutoGenerateError.transcriptionFailed,
        );
      }
      lrc = value;
    } on FirebaseFunctionsException catch (e, s) {
      debugPrint('Firebase Funcion generate_lyrics: $e');
      // 唯一上報點(背景 runner 端不再重複報)。未登入 / 配額滿屬
      // 使用者狀態非 bug,不上報。
      if (e.code != 'unauthenticated' && e.code != 'resource-exhausted') {
        reportError(e, s, reason: 'generate_lyrics 失敗（code=${e.code}）');
      }
      throw LyricsAutoGenerateException(_mapFunctionsError(e));
    }

    // 沿用唯一索引 replace 寫入;來源 / 格式為自動產生產物。
    final generated = LyricsEntity()
      ..trackId = trackId
      ..title = title
      ..format = LyricsFormat.lrc
      ..source = LyricsSource.generated
      ..content = lrc
      ..addedAt = DateTime.now();
    await _ref.read(lyricsRepositoryProvider).save(generated);
    _ref.invalidate(trackLyricsProvider(trackId));
  }

  LyricsAutoGenerateError _mapFunctionsError(FirebaseFunctionsException e) =>
      switch (e.code) {
        'unauthenticated' => LyricsAutoGenerateError.notLoggedIn,
        'resource-exhausted' => LyricsAutoGenerateError.rateLimited,
        'failed-precondition' => LyricsAutoGenerateError.transcriptionFailed,
        'unavailable' || 'deadline-exceeded' => LyricsAutoGenerateError.network,
        _ => LyricsAutoGenerateError.unknown,
      };
}

final lyricsAutoGenerateServiceProvider = Provider<LyricsAutoGenerateService>(
  (ref) => LyricsAutoGenerateService(ref),
);
