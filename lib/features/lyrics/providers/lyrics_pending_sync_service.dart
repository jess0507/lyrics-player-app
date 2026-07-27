import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crash_reporter.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../background/lyrics_background_protocol.dart';
import '../background/lyrics_background_runner.dart';
import '../background/lyrics_l10n_resolver.dart';
import '../models/lyrics_entity.dart';
import '../models/lyrics_job_status.dart';
import '../services/lyrics_repository.dart';
import 'lyrics_pending_sync_store.dart';
import 'track_lyrics_provider.dart';

/// 依 [lyricsPendingSyncStoreProvider] 持久化的 trackId 清單,逐一訂閱其
/// Firestore 文件(`users/{uid}/lyrics/{trackId}`)。背景任務(queued)送出
/// 後,Cloud Run 端完成的結果原本只寫進 Firestore——要等使用者剛好再次對
/// 同一 trackId 觸發命中 cached 分支,或重新登入觸發全量還原,才會回到
/// 本機。這段空窗期若中間有其他歌詞變更觸發全量推送,雲端這份快照會被
/// `LyricsSync.push` 當「本機沒有的多餘文件」誤刪。
///
/// 本服務補上這段空窗:狀態轉終態時,done 的話把文件內容直接存回本機
/// Isar(同一份文件已含 content/format/title,見後端 `_save_lyrics_snapshot`),
/// 兩種終態(done / failed)都會發最終確認通知(原生通知 + app 內
/// SnackBar,見 [_notifyResult]),並把該 trackId 從本地待處理清單移除。
/// 於 `app.dart` 根層級常駐 watch,不綁定特定頁面,跨 app 重啟也能接續。
class LyricsPendingSyncService {
  LyricsPendingSyncService(this._ref) {
    _init();
  }

  final Ref _ref;
  final _subscriptions =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};

  void _init() {
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
    for (final trackId in jobs.keys) {
      if (_subscriptions.containsKey(trackId) || uid == null) continue;
      debugPrint('[LyricsPendingSyncService] start watching trackId:$trackId');
      _subscriptions[trackId] = _watch(uid, trackId);
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
  ) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('lyrics')
      .doc(trackId)
      .snapshots()
      .listen(
        (snapshot) => _onSnapshot(trackId, snapshot),
        onError: (Object e, StackTrace s) => reportError(
          e,
          s,
          reason: 'LyricsPendingSyncService 監聽 Firestore 失敗:trackId=$trackId',
        ),
      );

  void _onSnapshot(
    String trackId,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final phase = LyricsJobPhase.fromWire(snapshot.data()?['status'] as String?);
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
    debugPrint('[LyricsPendingSyncService] trackId:$trackId terminal phase:$phase');
    final job = _ref.read(lyricsPendingSyncStoreProvider)[trackId];
    final success =
        phase == LyricsJobPhase.done && await _syncContent(trackId, data);
    if (job != null) {
      await _notifyResult(job, success: success);
    }
    await _ref.read(lyricsPendingSyncStoreProvider.notifier).remove(trackId);
  }

  /// 存回本機 Isar,成功回 true。
  Future<bool> _syncContent(String trackId, Map<String, dynamic>? data) async {
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
      ..content = content
      ..addedAt = DateTime.now();
    await _ref.read(lyricsRepositoryProvider).save(entity);
    _ref.invalidate(trackLyricsProvider(trackId));
    debugPrint('[LyricsPendingSyncService] trackId:$trackId synced content, format:$format');
    return true;
  }

  /// 終態確認:同時嘗試原生通知(前景服務早已結束,走 app 常駐的 launcher
  /// channel,見 [LyricsBackgroundRunner.notifyResult])與 app 內
  /// SnackBar(app 當下在前景時比通知更即時;不在前景 / navigator 未就緒
  /// 時 [rootNavigatorKey.currentContext] 為 null,靜默略過)。
  Future<void> _notifyResult(LyricsPendingSyncJob job, {required bool success}) async {
    final l10n = resolveLyricsL10n(_ref);
    final text = switch ((job.mode, success)) {
      (LyricsBackgroundMode.generate, true) => l10n.lyrics_auto_generate_success,
      (LyricsBackgroundMode.generate, false) => l10n.lyrics_auto_generate_failed,
      (LyricsBackgroundMode.align, true) => l10n.lyrics_auto_sync_success,
      (LyricsBackgroundMode.align, false) => l10n.lyrics_auto_sync_failed,
    };
    debugPrint(
      '[LyricsPendingSyncService] notify title:${job.title}, mode:${job.mode.name}, success:$success',
    );
    await _ref
        .read(lyricsBackgroundRunnerProvider)
        .notifyResult(title: job.title, text: text);
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar('${job.title}：$text');
  }
}

final lyricsPendingSyncServiceProvider = Provider<LyricsPendingSyncService>(
  (ref) => LyricsPendingSyncService(ref),
);
