import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_protocol.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_runner.dart';
import 'package:seek_player/features/lyrics/background/lyrics_l10n_resolver.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/models/lyrics_job_status.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';

/// 依 [lyricsPendingSyncStoreProvider] 持久化的待同步清單,逐一訂閱各任務的
/// Firestore 文件(`user/{uid}/lyrics/{jobId}`)。背景任務(queued)送出
/// 後,Cloud Run 端完成的結果只寫進 Firestore,不會自己回到本機。這個子集合是後端專屬的投遞點,client 只讀不寫(client 自己的
/// 備份走 `user/{uid}/backupLyrics`,見 LyricsSync)。
///
/// 本服務補上這段空窗:狀態轉終態時,done 的話把文件內容直接存回本機
/// Isar(同一份文件已含 content/format/title,見後端 `_save_lyrics_snapshot`),
/// 兩種終態(done / failed)都會發最終確認通知(原生通知 + app 內
/// toast,見 [_notifyResult]),並把該 trackId 從本地待處理清單移除。
/// 寫回的新歌詞 entity 不帶 jobId;失敗則以 [LyricsRepository.clearJob] 收尾。
/// 於 `app.dart` 根層級常駐 watch,不綁定特定頁面,跨 app 重啟也能接續。
class LyricsPendingSyncService {
  LyricsPendingSyncService(this._ref) {
    _init();
  }

  final Ref _ref;
  final _subscriptions =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};

  void _init() {
    if (!_ref.read(firebaseAvailableProvider)) {
      debugPrint('[LyricsPendingSyncService] Firebase 不可用，停用同步');
      return;
    }
    _ref.listen<Map<String, LyricsPendingSyncJob>>(
      lyricsPendingSyncStoreProvider,
      (_, next) => _reconcile(next),
      fireImmediately: true,
    );
    _ref.onDispose(() {
      for (final sub in _subscriptions.values) {
        sub.cancel();
      }
      _subscriptions.clear();
    });
  }

  /// 本地清單有新增就開始訂閱;清單裡消失(已被本類別自己移除)就取消訂閱。
  /// 未登入時無法讀 Firestore,略過——留在清單裡,下次清單變動再重試。
  void _reconcile(Map<String, LyricsPendingSyncJob> jobs) {
    debugPrint('[LyricsPendingSyncService] reconcile pending:${jobs.keys}');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    for (final MapEntry(key: trackId, value: job) in jobs.entries) {
      if (_subscriptions.containsKey(trackId) || uid == null) continue;
      debugPrint(
        '[LyricsPendingSyncService] start watching trackId:$trackId, '
        'jobId:${job.jobId}',
      );
      _subscriptions[trackId] = _watch(uid, trackId, job.jobId);
    }
    for (final trackId in _subscriptions.keys.toList()) {
      if (!jobs.containsKey(trackId)) {
        debugPrint('[LyricsPendingSyncService] stop watching trackId:$trackId');
        _subscriptions.remove(trackId)?.cancel();
      }
    }
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _watch(
    String uid,
    String trackId,
    String jobId,
  ) => FirebaseFirestore.instance
      .collection('user')
      .doc(uid)
      .collection('lyrics')
      .doc(jobId)
      .snapshots()
      .listen(
        (snapshot) => _onSnapshot(trackId, snapshot),
        onError: (Object e, StackTrace s) => reportError(
          e,
          s,
          reason:
              'LyricsPendingSyncService 監聽 Firestore 失敗:'
              'trackId=$trackId, jobId=$jobId',
        ),
      );

  void _onSnapshot(
    String trackId,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final phase = LyricsJobPhase.fromWire(
      snapshot.data()?['status'] as String?,
    );
    debugPrint('[LyricsPendingSyncService] trackId:$trackId, phase:$phase');
    if (phase == null || !phase.isTerminal) return;
    // 終態:取消這筆訂閱,避免文件之後任何變動再次觸發。
    _subscriptions.remove(trackId)?.cancel();
    unawaited(_onTerminal(trackId, phase, snapshot.data()));
  }

  Future<void> _onTerminal(
    String trackId,
    LyricsJobPhase phase,
    Map<String, dynamic>? data,
  ) async {
    debugPrint(
      '[LyricsPendingSyncService] trackId:$trackId terminal phase:$phase',
    );
    final job = _ref.read(lyricsPendingSyncStoreProvider)[trackId];
    final success =
        phase == LyricsJobPhase.done &&
        await _syncContent(trackId, data, mode: job?.mode);
    // 失敗:AI 產生的空內容佔位刪掉,對時則只清 jobId、保留原歌詞。
    if (!success) await _ref.read(lyricsRepositoryProvider).clearJob(trackId);
    if (job != null) {
      await _notifyResult(job, success: success);
    }
    await _ref.read(lyricsPendingSyncStoreProvider.notifier).remove(trackId);
  }

  /// 存回本機 Isar,成功回 true。
  ///
  /// 任務種類寫成 [LyricsEntity.kind] 以區分產生 / 對時:以任務文件上後端寫的
  /// `kind` 為準;舊版後端沒有這個欄位時退回本機待同步紀錄的 [mode],
  /// 兩邊都沒有就記為 unknown。
  Future<bool> _syncContent(
    String trackId,
    Map<String, dynamic>? data, {
    required LyricsBackgroundMode? mode,
  }) async {
    final content = data?['content'];
    if (content is! String || content.isEmpty) {
      // 後端回報 done 卻沒有內文:記下形狀以區分權限 / 資料異常。
      reportError(
        StateError('背景歌詞任務回報 done 但沒有 content:trackId=$trackId'),
        StackTrace.current,
        reason: 'LyricsPendingSyncService 快照內容缺失',
      );
      return false;
    }
    final format =
        LyricsFormat.values.asNameMap()[data?['format']] ?? LyricsFormat.lrc;
    final entity = LyricsEntity()
      ..trackId = trackId
      ..title = (data?['title'] as String?) ?? ''
      ..format = format
      ..source = LyricsSource.generated
      ..kind =
          LyricsKind.values.asNameMap()[data?['kind']] ??
          switch (mode) {
            LyricsBackgroundMode.generate => LyricsKind.generate,
            LyricsBackgroundMode.align => LyricsKind.align,
            null => LyricsKind.unknown,
          }
      ..content = content
      ..addedAt = DateTime.now();
    await _ref.read(lyricsRepositoryProvider).save(entity);
    _ref.invalidate(trackLyricsProvider(trackId));
    debugPrint(
      '[LyricsPendingSyncService] trackId:$trackId synced content, format:$format',
    );
    return true;
  }

  /// 終態確認:同時嘗試原生通知(前景服務早已結束,走 app 常駐的 launcher
  /// channel,見 [LyricsBackgroundRunner.notifyResult])與 app 內
  /// toast(app 當下在前景時比通知更即時;navigator 未就緒時
  /// [showAppToast] 自行靜默略過)。
  Future<void> _notifyResult(
    LyricsPendingSyncJob job, {
    required bool success,
  }) async {
    final l10n = resolveLyricsL10n(_ref);
    final text = switch ((job.mode, success)) {
      (LyricsBackgroundMode.generate, true) => l10n.lyrics_ai_generate_success,
      (LyricsBackgroundMode.generate, false) => l10n.lyrics_ai_generate_failed,
      (LyricsBackgroundMode.align, true) => l10n.lyrics_auto_align_success,
      (LyricsBackgroundMode.align, false) => l10n.lyrics_auto_align_failed,
    };
    debugPrint(
      '[LyricsPendingSyncService] notify title:${job.title}, mode:${job.mode.name}, success:$success',
    );
    await _ref
        .read(lyricsBackgroundRunnerProvider)
        .notifyResult(title: job.title, text: text);
    showAppToast('${job.title}：$text');
  }
}

final lyricsPendingSyncServiceProvider = Provider<LyricsPendingSyncService>(
  (ref) => LyricsPendingSyncService(ref),
);
