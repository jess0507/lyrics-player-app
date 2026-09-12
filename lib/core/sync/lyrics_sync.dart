import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 歌詞與 `user/{uid}/backupLyrics/{trackId}` 子集合的推送與還原(SyncService
/// 調度)。歌詞原文放不進主文件的 1 MiB 上限,逐曲一份文件;完整快照語意
/// (last-write-wins)。
///
/// 刻意與 `user/{uid}/lyrics/{trackId}` 分開:那個子集合是後端對時 / 產生
/// 任務的投遞點(含 `status` 欄位,由 LyricsPendingSyncService 監聽),
/// client 只讀不寫(firestore.rules 亦封鎖 client 寫入)。備份集合完全由
/// client 擁有,所以可以放心整份覆寫、刪除本機沒有的多餘文件。
class LyricsSync {
  LyricsSync(this._ref);

  final Ref _ref;

  /// client 備份歌詞的子集合名稱。
  static const collectionName = 'backupLyrics';

  /// 單曲歌詞內文超過此位元組數不上傳(Firestore 單一文件 1 MiB 上限,
  /// 留欄位與編碼餘裕)。匯入端上限同為 1 MiB,極端值可能超標。
  static const _maxContentBytes = 900 * 1024;

  BackupStateStore get _store => _ref.read(backupStateStoreProvider);

  /// 一次性補記,讓下一個同步班次把存量歌詞推上雲端(SyncService 的
  /// _shouldPush:本機 lyricsModifiedAt 為 null 時不會觸發推送)。
  void markExistingPending() {
    if (_store.lyricsModifiedAt != null) return;
    if (_ref.read(lyricsRepositoryProvider).getAllSync().isEmpty) return;
    debugPrint('[Sync] 補記存量歌詞為待推送');
    _store.markLyricsModified();
  }

  /// 歌詞全量推送 [userDoc] 的 `backupLyrics` 子集合:先刪本機沒有的雲端
  /// 文件,再整批重寫本機所有歌詞。
  Future<void> push(DocumentReference<Map<String, dynamic>> userDoc) async {
    final local = _ref.read(lyricsRepositoryProvider).getAllSync();
    final col = userDoc.collection(collectionName);
    final cloudIds = (await col.get()).docs.map((d) => d.id).toSet();

    // WriteBatch 上限 500 個操作,分批送出。
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
    final stale = cloudIds.difference(localIds);
    for (final id in stale) {
      await addOp((b) => b.delete(col.doc(id)));
    }
    var skipped = 0;
    for (final e in local) {
      if (utf8.encode(e.content).length > _maxContentBytes) {
        skipped++;
        debugPrint('[Sync] 歌詞過大跳過上傳:trackId=${e.trackId}');
        continue;
      }
      await addOp(
        (b) => b.set(col.doc(e.trackId), {
          'title': e.title,
          'format': e.format.name,
          'source': e.source.name,
          'content': e.content,
          'updatedAt': e.addedAt.millisecondsSinceEpoch,
        }),
      );
    }
    if (pendingOps > 0) await batch.commit();
    debugPrint(
      '[Sync] 已上傳 ${local.length - skipped} 曲歌詞'
      '(刪除雲端 ${stale.length} 曲,略過 $skipped 曲)',
    );
  }

  /// 以 [userDoc] 的 `backupLyrics` 子集合整份覆寫本機歌詞(空集合也覆寫)。
  Future<void> restore(DocumentReference<Map<String, dynamic>> userDoc) async {
    final docs = await userDoc.collection(collectionName).get();
    await _ref
        .read(lyricsRepositoryProvider)
        .restoreFromRemote(docs.toLyricsEntities());
    // 歌詞顯示 provider 不走 Isar watch,還原後手動作廢重讀。
    _ref.invalidate(trackLyricsProvider);
  }
}

final lyricsSyncProvider = Provider<LyricsSync>((ref) => LyricsSync(ref));

/// 雲端 `backupLyrics` 子集合快照 -> 歌詞實體的解碼,容錯:缺欄位給預設值、
/// 沒有內文的文件跳過(原文是解析的唯一依據,空內文無意義)。
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
            (data['updatedAt'] as num? ?? 0).toInt(),
          ),
      );
    }
    return entities;
  }
}
