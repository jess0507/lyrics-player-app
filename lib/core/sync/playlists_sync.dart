import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

/// 播放清單與 `playlist` 子集合（一份清單一份文件，docId 為本機 Isar id）
/// 的推送與還原（SyncService 調度）。
class PlaylistsSync {
  PlaylistsSync(this._ref);

  final Ref _ref;

  /// 全量推送 [userDoc] 的 `playlist` 子集合：先刪本機沒有的雲端清單文件，
  /// 再整批重寫本機所有清單。與主文件同為完整快照語意
  /// （last-write-wins，不合併）。
  Future<void> push(DocumentReference<Map<String, dynamic>> userDoc) async {
    final playlists = _ref.read(playlistRepositoryProvider).getAllSync();
    final col = userDoc.collection('playlist');
    final cloudIds = (await col.get()).docs.map((d) => d.id).toSet();
    final localIds = {for (final p in playlists) '${p.id}'};

    final firestore = userDoc.firestore;
    var batch = firestore.batch();
    var pendingOps = 0;
    Future<void> addOp(void Function(WriteBatch b) op) async {
      op(batch);
      // WriteBatch 上限 500 個操作，分批送出。
      if (++pendingOps < 400) return;
      await batch.commit();
      batch = firestore.batch();
      pendingOps = 0;
    }

    for (final stale in cloudIds.difference(localIds)) {
      await addOp((b) => b.delete(col.doc(stale)));
    }
    for (final p in playlists) {
      await addOp(
        (b) => b.set(col.doc('${p.id}'), {
          'name': p.name,
          'isFavorites': p.isFavorites,
          'isRecentlyPlayed': p.isRecentlyPlayed,
          'createdAt': p.createdAt.millisecondsSinceEpoch,
          'trackIds': p.trackIds,
          'recentlyPlayed': [
            for (final e in p.recentlyPlayed)
              {
                'trackId': e.trackId,
                'playedAt': e.playedAt.millisecondsSinceEpoch,
              },
          ],
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    }
    if (pendingOps > 0) await batch.commit();
  }

  /// 以 [userDoc] 的 `playlist` 子集合整份覆寫本機清單（含我的最愛；
  /// 空集合也整份覆寫）。
  Future<void> restore(DocumentReference<Map<String, dynamic>> userDoc) async {
    final snapshot = await userDoc.collection('playlist').get();
    await _ref
        .read(playlistRepositoryProvider)
        .restoreFromRemote(snapshot.toPlaylists());
  }
}

final playlistsSyncProvider = Provider<PlaylistsSync>(
  (ref) => PlaylistsSync(ref),
);

/// 雲端 `playlist` 子集合快照 -> 播放清單實體的解碼（文件 id 即本機
/// Isar id），容錯：缺欄位給預設值、id 非數字的文件跳過。
extension _RemotePlaylistsDecode on QuerySnapshot<Map<String, dynamic>> {
  List<PlaylistEntity> toPlaylists() => [
    for (final doc in docs)
      if (int.tryParse(doc.id) case final id?)
        PlaylistEntity()
          ..id = id
          ..name = (doc.data()['name'] as String?) ?? ''
          ..isFavorites = (doc.data()['isFavorites'] as bool?) ?? false
          ..isRecentlyPlayed =
              (doc.data()['isRecentlyPlayed'] as bool?) ?? false
          ..createdAt = DateTime.fromMillisecondsSinceEpoch(
            (doc.data()['createdAt'] as num? ?? 0).toInt(),
          )
          ..trackIds = [
            for (final t in (doc.data()['trackIds'] as List? ?? const [])) '$t',
          ]
          ..recentlyPlayed = [
            for (final e in (doc.data()['recentlyPlayed'] as List? ?? const []))
              if (e is Map)
                RecentlyPlayedEntry()
                  ..trackId = '${e['trackId']}'
                  ..playedAt = DateTime.fromMillisecondsSinceEpoch(
                    (e['playedAt'] as num? ?? 0).toInt(),
                  ),
          ],
  ];
}
