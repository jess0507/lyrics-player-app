import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/sync/domain_backup.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

/// 播放清單 ↔ `playlists.json`:
/// `{ "playlists": [ {id, name, isFavorites, isRecentlyPlayed, createdAt,
/// trackIds, recentlyPlayed: [{trackId, playedAt}]} ] }`,
/// id 即本機 Isar id,時間一律毫秒 int。整份快照語意(last-write-wins)。
class PlaylistsBackup implements DomainBackup {
  PlaylistsBackup(this._ref);

  final Ref _ref;

  @override
  String get fileName => 'playlists.json';

  @override
  String get label => 'playlists';

  @override
  DateTime? get localModifiedAt =>
      _ref.read(syncStateStoreProvider).playlistModifiedAt;

  @override
  Map<String, dynamic> encode() =>
      encodePlaylists(_ref.read(playlistRepositoryProvider).getAllSync());

  @override
  Future<void> restore(Map<String, dynamic> json) => _ref
      .read(playlistRepositoryProvider)
      .restoreFromRemote(decodePlaylists(json));

  /// 純函式,供測試 round-trip。
  static Map<String, dynamic> encodePlaylists(List<PlaylistEntity> playlists) =>
      {
        'playlists': [
          for (final p in playlists)
            {
              'id': p.id,
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
            },
        ],
      };

  /// 容錯:缺欄位給預設值、id 非整數的清單跳過。
  static List<PlaylistEntity> decodePlaylists(Map<String, dynamic> json) => [
    for (final item in (json['playlists'] as List? ?? const []))
      if (item is Map)
        if (item['id'] case final num id)
          PlaylistEntity()
            ..id = id.toInt()
            ..name = (item['name'] as String?) ?? ''
            ..isFavorites = (item['isFavorites'] as bool?) ?? false
            ..isRecentlyPlayed = (item['isRecentlyPlayed'] as bool?) ?? false
            ..createdAt = DateTime.fromMillisecondsSinceEpoch(
              (item['createdAt'] as num? ?? 0).toInt(),
            )
            ..trackIds = [
              for (final t in (item['trackIds'] as List? ?? const [])) '$t',
            ]
            ..recentlyPlayed = [
              for (final e in (item['recentlyPlayed'] as List? ?? const []))
                if (e is Map)
                  RecentlyPlayedEntry()
                    ..trackId = '${e['trackId']}'
                    ..playedAt = DateTime.fromMillisecondsSinceEpoch(
                      (e['playedAt'] as num? ?? 0).toInt(),
                    ),
            ],
  ];
}

final playlistsBackupProvider = Provider<PlaylistsBackup>(
  (ref) => PlaylistsBackup(ref),
);
