import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/features/music_list/services/track_repository.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

/// 播放清單與 `user/{uid}/playlist` 子集合(一份清單一份文件,docId 為本機
/// Isar id)的推送與還原(SyncService 調度)。
class PlaylistsSync {
  PlaylistsSync(this._ref);

  final Ref _ref;

  /// 全量推送 [userDoc] 的 `playlist` 子集合:先刪本機沒有的雲端清單文件,
  /// 再整批重寫本機所有清單。完整快照語意(last-write-wins,不合併)。
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
      // WriteBatch 上限 500 個操作,分批送出。
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
          'sortField': p.sortField,
          'sortDescending': p.sortDescending,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    }
    if (pendingOps > 0) await batch.commit();
  }

  /// 本機是否有使用者資料(預設的空系統清單不算,見 [_hasUserContent])。
  bool hasLocalData() => _ref
      .read(playlistRepositoryProvider)
      .getAllSync()
      .any((p) => p._hasUserContent);

  /// 雲端 `playlist` 子集合是否有使用者資料(判斷同 [hasLocalData])。
  Future<bool> hasRemoteData(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async {
    final snapshot = await userDoc.collection('playlist').get();
    return snapshot.toPlaylists().any((p) => p._hasUserContent);
  }

  /// 以 [userDoc] 的 `playlist` 子集合整份覆寫本機清單(含我的最愛;
  /// 空集合也整份覆寫)。
  Future<void> restore(DocumentReference<Map<String, dynamic>> userDoc) async {
    final playlists = await _fetchRemote(userDoc);
    await _ref.read(playlistRepositoryProvider).restoreFromRemote(playlists);
  }

  /// 把雲端清單併進本機(結果寫回本機,不推送),規則見 [mergePlaylists]。
  Future<void> merge(DocumentReference<Map<String, dynamic>> userDoc) async {
    final remote = await _fetchRemote(userDoc);
    final repo = _ref.read(playlistRepositoryProvider);
    // 本機在 await 之後才讀,縮小與使用者操作交錯的空檔。
    await repo.restoreFromRemote(mergePlaylists(repo.getAllSync(), remote));
  }

  /// 讀雲端 `playlist` 子集合。清單成員 / 最近播放中找不到 track(本機
  /// 沒有對應的 TrackEntity 或檔案已不存在)的曲目濾掉,下次推送自然不帶。
  Future<List<PlaylistEntity>> _fetchRemote(
    DocumentReference<Map<String, dynamic>> userDoc,
  ) async {
    final snapshot = await userDoc.collection('playlist').get();
    final playlists = snapshot.toPlaylists();
    final available = _ref.read(trackRepositoryProvider).availableTrackIds([
      for (final p in playlists) ...[
        ...p.trackIds,
        for (final e in p.recentlyPlayed) e.trackId,
      ],
    ]);
    for (final p in playlists) {
      p
        ..trackIds = [
          for (final id in p.trackIds)
            if (available.contains(id)) id,
        ]
        ..recentlyPlayed = [
          for (final e in p.recentlyPlayed)
            if (available.contains(e.trackId)) e,
        ];
    }
    return playlists;
  }
}

/// 播放清單合併(登入同步、本機與雲端都有資料時),以 id 對齊、以雲端
/// 為主:雲端的清單整份照用(同 id 的本機清單捨棄),本機只有雲端沒有的
/// id 才保留。
///
/// 例外:我的最愛 / 最近播放是唯一的系統清單,雲端已有時,本機 id 不同
/// 的那份也捨棄,避免出現兩份我的最愛。
List<PlaylistEntity> mergePlaylists(
  List<PlaylistEntity> local,
  List<PlaylistEntity> remote,
) {
  final remoteIds = {for (final r in remote) r.id};
  final remoteHasFavorites = remote.any((r) => r.isFavorites);
  final remoteHasRecent = remote.any((r) => r.isRecentlyPlayed);
  return [
    ...remote,
    for (final l in local)
      if (!remoteIds.contains(l.id) &&
          !(l.isFavorites && remoteHasFavorites) &&
          !(l.isRecentlyPlayed && remoteHasRecent))
        l,
  ];
}

final playlistsSyncProvider = Provider<PlaylistsSync>(
  (ref) => PlaylistsSync(ref),
);

/// 雲端 `playlist` 子集合快照 -> 播放清單實體的解碼(文件 id 即本機
/// Isar id),容錯:缺欄位給預設值、id 非數字的文件跳過。
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
          ..sortField = doc.data()['sortField'] as String?
          ..sortDescending = doc.data()['sortDescending'] as bool?
          ..trackIds = [
            for (final t in (doc.data()['trackIds'] as List? ?? const [])) '$t',
          ]
          ..recentlyPlayed = [
            for (final e in (doc.data()['recentlyPlayed'] as List? ?? const []))
              // 沒有 trackId 的是舊格式,對不到任何本機曲目。
              if (e is Map && e['trackId'] is String)
                RecentlyPlayedEntry()
                  ..trackId = e['trackId'] as String
                  ..playedAt = DateTime.fromMillisecondsSinceEpoch(
                    (e['playedAt'] as num? ?? 0).toInt(),
                  ),
          ],
  ];
}

/// 登入同步判斷「有沒有資料」用:自建清單一律算;我的最愛 / 最近播放是
/// 預設存在的系統清單,有曲目才算。
extension _PlaylistUserContent on PlaylistEntity {
  bool get _hasUserContent =>
      (!isFavorites && !isRecentlyPlayed) ||
      trackIds.isNotEmpty ||
      recentlyPlayed.isNotEmpty;
}
