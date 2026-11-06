import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/music_list/services/track_md5_service.dart';
import 'package:seek_player/features/lyrics/services/lyrics_parser.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';
import 'package:seek_player/features/lyrics/services/track_audio_resolver.dart';
import 'package:seek_player/features/lyrics/auto_align/audio_compressor.dart';
import 'package:seek_player/features/lyrics/usage_limit/audio_duration_probe.dart';

/// 必須與 Cloud Functions 部署的 region(`functions/main.py` 的 `_REGION`)一致。
const _functionsRegion = 'asia-east1';

/// 對時流程的階段,供進度 UI 顯示。
enum LyricsAutoAlignStep { compressing, uploading, aligning }

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
enum LyricsAutoAlignError {
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

class LyricsAutoAlignException implements Exception {
  const LyricsAutoAlignException(this.error, {this.activeTitle});

  final LyricsAutoAlignError error;

  /// [error] 為 [LyricsAutoAlignError.busy] 且是後端回報「別首歌正在處理中」
  /// 時,該曲的曲名,供訊息顯示;其餘情況為 null。
  final String? activeTitle;
}

/// 歌詞自動對時:讀本機音訊 → 壓縮 → 上傳 GCS → 呼叫 `align_lyrics` callable。
/// 後端把工作丟進 Cloud Tasks 後**立刻回應,不等對時完成**(見
/// `functions/main.py` `align_lyrics`)——`autoAlign` 成功返回只代表「已送出
/// 背景處理」,**不保證歌詞已經產生完成**。本方法只負責壓縮 / 上傳 / 呼叫
/// callable 這段,不碰本機 Isar 也不管 Firestore 是否已有現成快照;把結果
/// 寫回本機統一交給 [LyricsPendingSyncService] 處理——呼叫端(見
/// `LyricsAutoAlignController.run`)必須在呼叫本方法**之前**就把 pathKey 加進
/// `lyricsPendingSyncStoreProvider`,該服務才會開始監聽 Firestore 狀態,
/// 不論這次是後端立即回應(現成快照)還是真的要背景跑一段時間,終態都會
/// 由它寫回本機。
///
/// 失敗一律不寫半套時間:任一步出錯時保留原本的純文字歌詞。
class LyricsAutoAlignService {
  LyricsAutoAlignService(this._ref);

  final Ref _ref;

  /// 為 [pathKey] 執行對時,後端任務文件為 `user/{uid}/lyrics/{jobId}`。[language] 為語言提示(BCP-47,後端正規化)。
  /// [engine] 指定後端對齊引擎(aeneas / WhisperX)。各階段以 [onStep] 回報
  /// 進度。成功僅代表已送出 callable,失敗拋 [LyricsAutoAlignException]。
  Future<void> autoAlign({
    required String pathKey,
    required String jobId,
    required String title,
    required String language,
    required LyricsAlignEngine engine,
    void Function(LyricsAutoAlignStep step)? onStep,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const LyricsAutoAlignException(LyricsAutoAlignError.notLoggedIn);
    }

    final repo = _ref.read(lyricsRepositoryProvider);
    final entity = repo.findByPathKey(pathKey);
    if (entity == null) {
      throw const LyricsAutoAlignException(LyricsAutoAlignError.noLyrics);
    }
    // 取非空白行送對齊(與後端「再濾掉空行」一一對應)。
    final lines = [
      for (final line in parseLyrics(entity.content, entity.format).lines)
        if (line.text.trim().isNotEmpty) line.text.trim(),
    ];
    if (lines.isEmpty) {
      throw const LyricsAutoAlignException(LyricsAutoAlignError.noLyrics);
    }

    final audioPath = await _ref
        .read(trackAudioResolverProvider)
        .resolve(pathKey);
    if (audioPath == null) {
      throw const LyricsAutoAlignException(LyricsAutoAlignError.noAudio);
    }
    // 後端以「音檔 MD5 + 歌詞 MD5」判斷同一個對時任務、沿用成功過的結果:
    // 歌詞改過(例如重新貼上)就是不同任務、會重新對齊。音檔 MD5 算不出來
    // (null)時後端不查快取、照常處理。
    final md5Service = _ref.read(trackMd5ServiceProvider);
    final trackMd5 = await md5Service.audioMd5(pathKey, audioPath);
    // 隨 callable 送出,讓後端派工前就確認剩餘額度足夠(權威檢查仍在
    // 後端量測實際音訊);量不到(null)就不送。
    final durationSeconds = await _ref
        .read(audioDurationProbeProvider)
        .durationSeconds(pathKey: pathKey, audioPath: audioPath);
    final lyricsMd5 = md5Service.lyricsMd5(pathKey, lines);

    onStep?.call(LyricsAutoAlignStep.compressing);
    final File compressed;
    try {
      compressed = await _ref
          .read(audioCompressorProvider)
          .compressForAlignment(audioPath);
    } on AudioCompressException catch (e, s) {
      reportError(e, s, reason: '歌詞對時：壓縮音訊失敗');
      throw const LyricsAutoAlignException(LyricsAutoAlignError.compressFailed);
    }

    onStep?.call(LyricsAutoAlignStep.uploading);
    final Reference storageRef;
    try {
      storageRef = FirebaseStorage.instance.ref('align/${user.uid}/$jobId.m4a');
      await storageRef.putFile(
        compressed,
        SettableMetadata(contentType: 'audio/mp4'),
      );
    } on FirebaseException catch (e, s) {
      reportError(e, s, reason: '歌詞對時：上傳音訊到 GCS 失敗');
      throw const LyricsAutoAlignException(LyricsAutoAlignError.uploadFailed);
    } finally {
      // 壓縮暫存檔已上傳(或上傳失敗),本機不再需要。
      unawaited(compressed.delete().catchError((_) => compressed));
    }

    onStep?.call(LyricsAutoAlignStep.aligning);
    try {
      final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable(
            'align_lyrics',
            // 後端派工到 Cloud Tasks 後立刻回應,不再需要等對時整首歌跑完,
            // 但保留較寬鬆逾時以應付偶發的冷啟動 / 網路延遲。
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
      await callable.call<Object?>({
        'lines': lines,
        'bucket': storageRef.bucket,
        'object': storageRef.fullPath,
        'language': language,
        'format': 'm4a',
        'engine': engine.wireName,
        // 任務文件 id(pathKey 含 `/` 不能當 Firestore doc id)。同一首歌的
        // 判斷改用 trackMd5,不再送已 deprecated 的 `trackId`。
        'jobId': jobId,
        'trackMd5': ?trackMd5,
        'durationSeconds': ?durationSeconds,
        'lyricsMd5': lyricsMd5,
        'title': title,
      });
      debugPrint('[LyricsAutoAlignService] pathKey:$pathKey, 已送出 align_lyrics');
    } on FirebaseFunctionsException catch (e, s) {
      final exception = _toException(e);
      // 唯一上報點(背景 runner 端不再重複報)。未登入 / 配額滿 / 已有其他
      // 曲目正在處理都屬於使用者狀態非 bug,不上報,只留本機 log。
      if (e.code != 'unauthenticated' &&
          e.code != 'resource-exhausted' &&
          exception.error != LyricsAutoAlignError.busy) {
        reportError(e, s, reason: 'align_lyrics 失敗（code=${e.code}）');
      } else {
        debugPrint('Firebase Function align_lyrics: $e');
      }
      throw exception;
    }
  }

  /// 把 callable 拋出的例外轉成 [LyricsAutoAlignException];後端因為「使用者
  /// 已有其他曲目正在處理中」拒絕(`failed-precondition` +
  /// `details.code == 'busy'`)時,一併取出正在處理中的曲名。
  LyricsAutoAlignException _toException(FirebaseFunctionsException e) {
    final details = e.details;
    if (e.code == 'failed-precondition' &&
        details is Map &&
        details['code'] == 'busy') {
      final activeTitle = details['activeTitle'];
      return LyricsAutoAlignException(
        LyricsAutoAlignError.busy,
        activeTitle: activeTitle is String && activeTitle.isNotEmpty
            ? activeTitle
            : null,
      );
    }
    return LyricsAutoAlignException(_mapFunctionsError(e));
  }

  LyricsAutoAlignError _mapFunctionsError(FirebaseFunctionsException e) =>
      switch (e.code) {
        'unauthenticated' => LyricsAutoAlignError.notLoggedIn,
        'resource-exhausted' => LyricsAutoAlignError.rateLimited,
        'failed-precondition' => LyricsAutoAlignError.alignmentFailed,
        'unavailable' || 'deadline-exceeded' => LyricsAutoAlignError.network,
        _ => LyricsAutoAlignError.unknown,
      };
}

final lyricsAutoAlignServiceProvider = Provider<LyricsAutoAlignService>(
  (ref) => LyricsAutoAlignService(ref),
);
