import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/lyrics/auto_sync/audio_compressor.dart';
import 'package:seek_player/features/lyrics/services/track_audio_resolver.dart';

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
  const LyricsAutoGenerateException(this.error, {this.activeTitle});

  final LyricsAutoGenerateError error;

  /// [error] 為 [LyricsAutoGenerateError.busy] 且是後端回報「別首歌正在
  /// 處理中」時,該曲的曲名,供訊息顯示;其餘情況為 null。
  final String? activeTitle;
}

/// 歌詞自動產生:讀本機音訊 → 壓縮 → 上傳 GCS → 呼叫 `generate_lyrics`
/// callable。後端把工作丟進 Cloud Tasks 後**立刻回應,不等轉寫完成**——
/// `generate` 成功返回只代表「已送出背景處理」,**不保證歌詞已經產生完成**。
/// 本方法只負責壓縮 / 上傳 / 呼叫 callable 這段,不碰本機 Isar 也不管
/// Firestore 是否已有現成快照;把結果寫回本機統一交給
/// [LyricsPendingSyncService] 處理——呼叫端(見
/// `LyricsAutoGenerateController.run`)必須在呼叫本方法**之前**就把
/// trackId 加進 `lyricsPendingSyncStoreProvider`,該服務才會開始監聽
/// Firestore 狀態,不論這次是後端立即回應(現成快照)還是真的要背景跑一段
/// 時間,終態都會由它寫回本機。
class LyricsAutoGenerateService {
  LyricsAutoGenerateService(this._ref);

  final Ref _ref;

  /// 為 [trackId] 執行自動產生。各階段以 [onStep] 回報進度。成功僅代表已
  /// 送出 callable,失敗拋 [LyricsAutoGenerateException]。
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
    try {
      final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable(
            'generate_lyrics',
            // 後端派工到 Cloud Tasks 後立刻回應,不再需要等轉寫整首歌跑完,
            // 但保留較寬鬆逾時以應付偶發的冷啟動 / 網路延遲。
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
      // 不送 language:交由後端自動偵測歌曲語言。
      await callable.call<Object?>({
        'bucket': storageRef.bucket,
        'object': storageRef.fullPath,
        'format': 'm4a',
        'trackId': trackId,
        'title': title,
      });
      debugPrint(
        '[LyricsAutoGenerateService] trackId:$trackId, 已送出 generate_lyrics',
      );
    } on FirebaseFunctionsException catch (e, s) {
      debugPrint('Firebase Funcion generate_lyrics: $e');
      final exception = _toException(e);
      // 唯一上報點(背景 runner 端不再重複報)。未登入 / 配額滿 / 已有其他
      // 曲目正在處理都屬於使用者狀態非 bug,不上報。
      if (e.code != 'unauthenticated' &&
          e.code != 'resource-exhausted' &&
          exception.error != LyricsAutoGenerateError.busy) {
        reportError(e, s, reason: 'generate_lyrics 失敗(code=${e.code})');
      }
      throw exception;
    }
  }

  /// 把 callable 拋出的例外轉成 [LyricsAutoGenerateException];後端因為
  /// 「使用者已有其他曲目正在處理中」拒絕(`failed-precondition` +
  /// `details.code == 'busy'`)時,一併取出正在處理中的曲名。
  LyricsAutoGenerateException _toException(FirebaseFunctionsException e) {
    final details = e.details;
    if (e.code == 'failed-precondition' &&
        details is Map &&
        details['code'] == 'busy') {
      final activeTitle = details['activeTitle'];
      return LyricsAutoGenerateException(
        LyricsAutoGenerateError.busy,
        activeTitle: activeTitle is String && activeTitle.isNotEmpty
            ? activeTitle
            : null,
      );
    }
    return LyricsAutoGenerateException(_mapFunctionsError(e));
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
