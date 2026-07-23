import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    var cached = false;
    try {
      final callable = FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable(
            'generate_lyrics',
            // 後端派工到 Cloud Tasks 後立刻回應,不再需要等轉寫整首歌跑完,
            // 但保留較寬鬆逾時以應付偶發的冷啟動 / 網路延遲。
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
      // 不送 language:交由後端自動偵測歌曲語言。
      final result = await callable.call<Object?>({
        'bucket': storageRef.bucket,
        'object': storageRef.fullPath,
        'format': 'm4a',
        'trackId': trackId,
        'title': title,
      });
      // 不同平台回傳 Map 的鍵型別不一,故動態取值。
      final data = result.data;
      cached = data is Map && data['cached'] == true;
    } on FirebaseFunctionsException catch (e, s) {
      debugPrint('Firebase Funcion generate_lyrics: $e');
      // 唯一上報點(背景 runner 端不再重複報)。未登入 / 配額滿屬
      // 使用者狀態非 bug,不上報。
      if (e.code != 'unauthenticated' && e.code != 'resource-exhausted') {
        reportError(e, s, reason: 'generate_lyrics 失敗(code=${e.code})');
      }
      throw LyricsAutoGenerateException(_mapFunctionsError(e));
    }

    if (!cached) {
      // 已成功送進背景處理佇列,歌詞尚未產生完成——不等待也不嘗試讀取,
      // 詳見本類別文件註解。
      return;
    }

    // 該 trackId 先前已產生過,Firestore 已有現成快照,立即讀回寫本機。
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('lyrics')
        .doc(trackId)
        .get();
    final content = snapshot.data()?['content'];
    if (content is! String || content.isEmpty) {
      // 後端宣稱有快照卻讀不到:記下形狀以區分權限 / 路徑問題。
      reportError(
        StateError(
          'generate_lyrics 回 cached 但讀不到 Firestore 快照:trackId=$trackId'
          ' exists=${snapshot.exists}',
        ),
        StackTrace.current,
        reason: 'generate_lyrics 快照讀回失敗',
      );
      throw const LyricsAutoGenerateException(
        LyricsAutoGenerateError.transcriptionFailed,
      );
    }

    // 沿用唯一索引 replace 寫入;來源 / 格式為自動產生產物。
    final generated = LyricsEntity()
      ..trackId = trackId
      ..title = title
      ..format = LyricsFormat.lrc
      ..source = LyricsSource.generated
      ..content = content
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
