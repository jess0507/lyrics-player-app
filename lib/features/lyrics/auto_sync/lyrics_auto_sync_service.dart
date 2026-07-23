import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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

/// 歌詞自動對時:讀本機音訊 → 壓縮 → 上傳 GCS → 呼叫 `align_lyrics` callable。
/// 後端把工作丟進 Cloud Tasks 後**立刻回應,不等對時完成**(見
/// `functions/main.py` `align_lyrics`)——`autoSync` 成功返回只代表「已送出
/// 背景處理」,**不保證歌詞已經產生完成**:
/// - 該 trackId 已有快照(`cached`)→ 立即讀回內文寫入本機 [LyricsEntity]
///   (`source = generated`、`format = lrc`),顯示端立刻可見。
/// - 否則(`queued`)→ 不等待、不嘗試讀取本機也不寫入;結果由 Cloud Run 端
///   背景算完後自行存入 `users/{uid}/lyrics/{trackId}`,下次開啟歌詞頁時
///   `trackLyricsProvider` 的 Firestore 快照降級路徑會自然讀到
///   (見 `providers/track_lyrics_provider.dart`)。
///
/// 讀回快照寫本機(`cached` 情形)是必要的,不只是圖方便:歌詞備份同步
/// (sync v5,見 `core/sync/lyrics_sync.dart`)是「本機 Isar 有什麼、雲端就
/// 整份覆寫成什麼」——若本機完全沒有這筆資料,之後任何其他歌詞變更觸發的
/// 全量同步,會把雲端這份快照當「本機沒有的多餘文件」誤刪。
///
/// 失敗一律不寫半套時間:任一步出錯時保留原本的純文字歌詞。
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
    var cached = false;
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: _functionsRegion,
      ).httpsCallable(
        'align_lyrics',
        // 後端派工到 Cloud Tasks 後立刻回應,不再需要等對時整首歌跑完,
        // 但保留較寬鬆逾時以應付偶發的冷啟動 / 網路延遲。
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call<Object?>({
        'lines': lines,
        'bucket': storageRef.bucket,
        'object': storageRef.fullPath,
        'language': language,
        'format': 'm4a',
        'engine': engine.wireName,
        'trackId': trackId,
        'title': title,
      });
      // 不同平台回傳 Map 的鍵型別不一,故動態取值。
      final data = result.data;
      cached = data is Map && data['cached'] == true;
    } on FirebaseFunctionsException catch (e, s) {
      debugPrint('Firebase Function align_lyrics: $e');
      // 唯一上報點(背景 runner 端不再重複報)。未登入 / 配額滿屬
      // 使用者狀態非 bug,不上報。
      if (e.code != 'unauthenticated' && e.code != 'resource-exhausted') {
        reportError(e, s, reason: 'align_lyrics 失敗（code=${e.code}）');
      }
      throw LyricsAutoSyncException(_mapFunctionsError(e));
    }

    if (!cached) {
      // 已成功送進背景處理佇列,歌詞尚未產生完成——不等待也不嘗試讀取,
      // 詳見本類別文件註解。
      return;
    }

    // 該 trackId 先前已對時 / 產生過,Firestore 已有現成快照,立即讀回寫本機。
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
          'align_lyrics 回 cached 但讀不到 Firestore 快照:trackId=$trackId'
          ' exists=${snapshot.exists}',
        ),
        StackTrace.current,
        reason: 'align_lyrics 快照讀回失敗',
      );
      throw const LyricsAutoSyncException(
        LyricsAutoSyncError.alignmentFailed,
      );
    }

    // 沿用唯一索引 replace 覆蓋原歌詞;來源 / 格式改為對時產物。
    final synced = LyricsEntity()
      ..trackId = trackId
      ..title = title
      ..format = LyricsFormat.lrc
      ..source = LyricsSource.generated
      ..content = content
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
