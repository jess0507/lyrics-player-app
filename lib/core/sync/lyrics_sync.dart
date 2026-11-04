import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/backup/backup_state_store.dart';
import 'package:seek_player/core/sync/track_doc_key.dart';
import 'package:seek_player/features/music_list/services/track_repository.dart';
import 'package:seek_player/features/lyrics/models/lyrics_entity.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';

/// 歌詞與 `user/{uid}/backupLyrics/{trackDocKey(pathKey)}` 子集合的推送與
/// 還原(SyncService 調度)。pathKey含 `/` 不能當 doc id,以
/// [trackDocKey] 轉換,原值存在文件的 `pathKey` 欄位。歌詞原文放不進主文件的 1 MiB 上限,逐曲一份文件;完整快照語意
/// (last-write-wins)。
///
/// 刻意與 `user/{uid}/lyrics/{jobId}` 分開:那個子集合是後端對時 / 產生
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

  /// 本機是否有歌詞。
  bool hasLocalData() =>
      _ref.read(lyricsRepositoryProvider).getAllSync().isNotEmpty;

  /// 雲端 `backupLyrics` 子集合是否非空。
  Future<bool> hasRemoteData(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async =>
      (await userDoc.collection(collectionName).limit(1).get()).docs.isNotEmpty;

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

    final localIds = {for (final e in local) trackDocKey(e.pathKey)};
    final stale = cloudIds.difference(localIds);
    for (final id in stale) {
      await addOp((b) => b.delete(col.doc(id)));
    }
    var skipped = 0;
    for (final e in local) {
      if (utf8.encode(e.content).length > _maxContentBytes) {
        skipped++;
        debugPrint('[Sync] 歌詞過大跳過上傳:pathKey=${e.pathKey}');
        continue;
      }
      await addOp(
        (b) => b.set(col.doc(trackDocKey(e.pathKey)), {
          'pathKey': e.pathKey,
          // 舊識別碼僅附帶保存,不作為比對依據(見 plans/33)。
          'trackId': ?e.trackId,
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
    await _ref
        .read(lyricsRepositoryProvider)
        .restoreFromRemote(await _fetchRemote(userDoc));
    // 歌詞顯示 provider 不走 Isar watch,還原後手動作廢重讀。
    _ref.invalidate(trackLyricsProvider);
  }

  /// 把雲端歌詞併進本機(結果寫回本機,不推送),規則見 [mergeLyrics]。
  Future<void> merge(DocumentReference<Map<String, dynamic>> userDoc) async {
    final remote = await _fetchRemote(userDoc);
    final repo = _ref.read(lyricsRepositoryProvider);
    await repo.restoreFromRemote(mergeLyrics(repo.getAllSync(), remote));
    _ref.invalidate(trackLyricsProvider);
  }

  /// 讀雲端 `backupLyrics` 子集合。找不到 track(本機沒有對應的
  /// TrackEntity 或檔案已不存在)的歌詞濾掉,下次推送自然不帶。
  Future<List<LyricsEntity>> _fetchRemote(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async {
    final docs = await userDoc.collection(collectionName).get();
    final entities = docs.toLyricsEntities();
    final available = _ref.read(trackRepositoryProvider).availablePathKeys([
      for (final e in entities) e.pathKey,
    ]);
    return [
      for (final e in entities)
        if (available.contains(e.pathKey)) e,
    ];
  }
}

/// 歌詞合併,以雲端為主:以 pathKey 對齊,兩邊都有的用雲端那份,只有
/// 本機有的保留。本機該曲有進行中的後端任務時把 jobId 帶過去,任務收尾
/// 才對得上(收尾後會以任務結果覆寫)。
List<LyricsEntity> mergeLyrics(
  List<LyricsEntity> local,
  List<LyricsEntity> remote,
) {
  final byTrack = {for (final e in local) e.pathKey: e};
  for (final r in remote) {
    final l = byTrack[r.pathKey];
    byTrack[r.pathKey] = l == null
        ? r
        : (r
            ..id = l.id
            ..jobId = l.jobId);
  }
  return byTrack.values.toList();
}

final lyricsSyncProvider = Provider<LyricsSync>((ref) => LyricsSync(ref));

/// 雲端 `backupLyrics` 子集合快照 -> 歌詞實體的解碼,容錯:缺欄位給預設值、
/// 沒有內文的文件跳過(原文是解析的唯一依據,空內文無意義)、沒有
/// `pathKey` 欄位的文件跳過(schema 8 以前以 sha1 指紋為 doc id 的舊格式,
/// 對不到任何本機曲目)。
extension _RemoteLyricsDecode on QuerySnapshot<Map<String, dynamic>> {
  List<LyricsEntity> toLyricsEntities() {
    final entities = <LyricsEntity>[];
    for (final doc in docs) {
      final data = doc.data();
      final content = data['content'];
      if (content is! String || content.isEmpty) continue;
      final pathKey = data['pathKey'];
      if (pathKey is! String || pathKey.isEmpty) continue;
      entities.add(
        LyricsEntity()
          ..pathKey = pathKey
          ..trackId = data['trackId'] as String?
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
