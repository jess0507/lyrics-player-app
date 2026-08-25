import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/lyrics/services/lyrics_parser.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';
import 'package:seek_player/features/lyrics/services/track_audio_resolver.dart';
import 'package:seek_player/features/lyrics/auto_sync/audio_compressor.dart';

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
  const LyricsAutoSyncException(this.error, {this.activeTitle});

  final LyricsAutoSyncError error;

  /// [error] 為 [LyricsAutoSyncError.busy] 且是後端回報「別首歌正在處理中」
  /// 時,該曲的曲名,供訊息顯示;其餘情況為 null。
  final String? activeTitle;
}

/// 歌詞自動對時:讀本機音訊 → 壓縮 → 上傳 GCS → 呼叫 `align_lyrics` callable。
/// 後端把工作丟進 Cloud Tasks 後**立刻回應,不等對時完成**(見
/// `functions/main.py` `align_lyrics`)——`autoSync` 成功返回只代表「已送出
/// 背景處理」,**不保證歌詞已經產生完成**。本方法只負責壓縮 / 上傳 / 呼叫
/// callable 這段,不碰本機 Isar 也不管 Firestore 是否已有現成快照;把結果
/// 寫回本機統一交給 [LyricsPendingSyncService] 處理——呼叫端(見
/// `LyricsAutoSyncController.run`)必須在呼叫本方法**之前**就把 trackId 加進
/// `lyricsPendingSyncStoreProvider`,該服務才會開始監聽 Firestore 狀態,
/// 不論這次是後端立即回應(現成快照)還是真的要背景跑一段時間,終態都會
/// 由它寫回本機。
///
/// 失敗一律不寫半套時間:任一步出錯時保留原本的純文字歌詞。
class LyricsAutoSyncService {
  LyricsAutoSyncService(this._ref);

  final Ref _ref;

  /// 為 [trackId] 執行對時。[language] 為語言提示(BCP-47,後端正規化)。
  /// [engine] 指定後端對齊引擎(aeneas / WhisperX)。各階段以 [onStep] 回報
  /// 進度。成功僅代表已送出 callable,失敗拋 [LyricsAutoSyncException]。
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
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: _functionsRegion,
      ).httpsCallable(
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
        'trackId': trackId,
        'title': title,
      });
      debugPrint('[LyricsAutoSyncService] trackId:$trackId, 已送出 align_lyrics');
    } on FirebaseFunctionsException catch (e, s) {
      final exception = _toException(e);
      // 唯一上報點(背景 runner 端不再重複報)。未登入 / 配額滿 / 已有其他
      // 曲目正在處理都屬於使用者狀態非 bug,不上報,只留本機 log。
      if (e.code != 'unauthenticated' &&
          e.code != 'resource-exhausted' &&
          exception.error != LyricsAutoSyncError.busy) {
        reportError(e, s, reason: 'align_lyrics 失敗（code=${e.code}）');
      } else {
        debugPrint('Firebase Function align_lyrics: $e');
      }
      throw exception;
    }
  }

  /// 把 callable 拋出的例外轉成 [LyricsAutoSyncException];後端因為「使用者
  /// 已有其他曲目正在處理中」拒絕(`failed-precondition` +
  /// `details.code == 'busy'`)時,一併取出正在處理中的曲名。
  LyricsAutoSyncException _toException(FirebaseFunctionsException e) {
    final details = e.details;
    if (e.code == 'failed-precondition' &&
        details is Map &&
        details['code'] == 'busy') {
      final activeTitle = details['activeTitle'];
      return LyricsAutoSyncException(
        LyricsAutoSyncError.busy,
        activeTitle: activeTitle is String && activeTitle.isNotEmpty
            ? activeTitle
            : null,
      );
    }
    return LyricsAutoSyncException(_mapFunctionsError(e));
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
