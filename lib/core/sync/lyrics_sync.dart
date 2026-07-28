import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/lyrics/models/lyrics_entity.dart';
import '../../features/lyrics/providers/track_lyrics_provider.dart';
import '../../features/lyrics/services/lyrics_repository.dart';
import 'sync_state_store.dart';

/// 歌詞與 `user/{uid}/lyrics/{trackId}` 子集合（sync v5）的推送與還原
/// （SyncService 調度）。歌詞原文放不進主文件的 1 MiB 上限，
/// 逐曲一份文件；與主文件同為完整快照語意（last-write-wins）。
class LyricsSync {
  LyricsSync(this._ref);

  final Ref _ref;

  /// 單曲歌詞內文超過此位元組數不上傳（Firestore 單一文件 1 MiB 上限，
  /// 留欄位與編碼餘裕）。匯入端上限同為 1 MiB，極端值可能超標。
  static const _maxContentBytes = 900 * 1024;

  SyncStateStore get _store => _ref.read(syncStateStoreProvider);

  /// 歌詞同步（v5）上線前既有的本機歌詞沒有 lyricsModifiedAt 記號；
  /// 一次性補記，讓下一個同步班次把存量歌詞推上雲端。
  void markExistingPending() {
    final store = _store;
    if (store.lyricsModifiedAt != null || store.lastLyricsSyncAt != null) {
      return;
    }
    if (_ref.read(lyricsRepositoryProvider).getAllSync().isEmpty) return;
    debugPrint('[Sync] 補記存量歌詞為待推送');
    store.markLyricsModified();
  }

  /// 自上次推送後歌詞有本機變更（含存量補記），需要推送子集合。
  bool get pushPending {
    final modified = _store.lyricsModifiedAt;
    if (modified == null) return false;
    final synced = _store.lastLyricsSyncAt;
    return synced == null || modified.isAfter(synced);
  }

  /// 歌詞全量推送 [userDoc] 的 `lyrics` 子集合：先刪本機沒有的雲端文件，
  /// 再整批重寫本機所有歌詞。
  Future<void> push(DocumentReference<Map<String, dynamic>> userDoc) async {
    final local = _ref.read(lyricsRepositoryProvider).getAllSync();
    final col = userDoc.collection('lyrics');
    final cloudIds = (await col.get()).docs.map((d) => d.id).toSet();

    // WriteBatch 上限 500 個操作，分批送出。
    final firestore = userDoc.firestore;
    var batch = firestore.batch();
    var pendingOps = 0;
    Future<void> addOp(void Function(WriteBatch b) op) async {
      op(batch);
      if (++pendingOps < 400) return;
      await batch.commit();
      batch = firestore.batch();
      pendingOps = 0;
    }

    final localIds = {for (final e in local) e.trackId};
    for (final stale in cloudIds.difference(localIds)) {
      await addOp((b) => b.delete(col.doc(stale)));
    }
    var skipped = 0;
    for (final e in local) {
      if (utf8.encode(e.content).length > _maxContentBytes) {
        skipped++;
        debugPrint('[Sync] 歌詞過大跳過上傳：trackId=${e.trackId}');
        continue;
      }
      await addOp(
        (b) => b.set(col.doc(e.trackId), {
          'title': e.title,
          'format': e.format.name,
          'source': e.source.name,
          'content': e.content,
          'addedAt': e.addedAt.millisecondsSinceEpoch,
        }),
      );
    }
    if (pendingOps > 0) await batch.commit();
    _store.markLyricsSynced();
    debugPrint(
      '[Sync] 已上傳 ${local.length - skipped} 曲歌詞'
      '（刪除雲端 ${cloudIds.difference(localIds).length} 曲）',
    );
  }

  /// 以 [userDoc] 的 `lyrics` 子集合整份覆寫本機歌詞（空集合也覆寫）。
  /// 僅在雲端文件為 v5+（子集合是權威來源）時由 SyncService 呼叫。
  Future<void> restore(DocumentReference<Map<String, dynamic>> userDoc) async {
    final docs = await userDoc.collection('lyrics').get();
    await _ref
        .read(lyricsRepositoryProvider)
        .restoreFromRemote(docs.toLyricsEntities());
    // 歌詞顯示 provider 不走 Isar watch，還原後手動作廢重讀。
    _ref.invalidate(trackLyricsProvider);
    _store.markLyricsSynced();
  }
}

final lyricsSyncProvider = Provider<LyricsSync>((ref) => LyricsSync(ref));

/// 雲端 `lyrics` 子集合快照 -> 歌詞實體的解碼，容錯：缺欄位給預設值、
/// 沒有內文的文件跳過（原文是解析的唯一依據，空內文無意義）。
extension _RemoteLyricsDecode on QuerySnapshot<Map<String, dynamic>> {
  List<LyricsEntity> toLyricsEntities() {
    final entities = <LyricsEntity>[];
    for (final doc in docs) {
      final data = doc.data();
      final content = data['content'];
      if (content is! String || content.isEmpty) continue;
      entities.add(
        LyricsEntity()
          ..trackId = doc.id
          ..title = (data['title'] as String?) ?? ''
          ..format =
              LyricsFormat.values.asNameMap()[data['format']] ??
              LyricsFormat.txt
          ..source =
              LyricsSource.values.asNameMap()[data['source']] ??
              LyricsSource.manual
          ..content = content
          ..addedAt = DateTime.fromMillisecondsSinceEpoch(
            (data['addedAt'] as num? ?? 0).toInt(),
          ),
      );
    }
    return entities;
  }
}
