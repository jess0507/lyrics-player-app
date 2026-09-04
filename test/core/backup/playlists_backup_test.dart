import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/core/backup/playlists_backup.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';

void main() {
  test('encode → JSON → decode round-trip 保留全部欄位', () {
    final favorites = PlaylistEntity()
      ..id = 1
      ..name = 'Fav'
      ..isFavorites = true
      ..createdAt = DateTime.fromMillisecondsSinceEpoch(1000)
      ..trackIds = ['a', 'b'];
    final recent = PlaylistEntity()
      ..id = 2
      ..name = 'Recent'
      ..isRecentlyPlayed = true
      ..createdAt = DateTime.fromMillisecondsSinceEpoch(2000)
      ..recentlyPlayed = [
        RecentlyPlayedEntry()
          ..trackId = 'c'
          ..playedAt = DateTime.fromMillisecondsSinceEpoch(3000),
      ];

    final json = jsonDecode(
      jsonEncode(PlaylistsBackup.encodePlaylists([favorites, recent])),
    );
    final decoded = PlaylistsBackup.decodePlaylists(json);

    expect(decoded, hasLength(2));
    expect(decoded[0].id, 1);
    expect(decoded[0].name, 'Fav');
    expect(decoded[0].isFavorites, isTrue);
    expect(decoded[0].isRecentlyPlayed, isFalse);
    expect(decoded[0].createdAt.millisecondsSinceEpoch, 1000);
    expect(decoded[0].trackIds, ['a', 'b']);
    expect(decoded[0].recentlyPlayed, isEmpty);

    expect(decoded[1].id, 2);
    expect(decoded[1].isRecentlyPlayed, isTrue);
    expect(decoded[1].trackIds, isEmpty);
    expect(decoded[1].recentlyPlayed.single.trackId, 'c');
    expect(
      decoded[1].recentlyPlayed.single.playedAt.millisecondsSinceEpoch,
      3000,
    );
  });

  test('缺欄位給預設值;id 非數字或非 Map 的條目跳過', () {
    final decoded = PlaylistsBackup.decodePlaylists({
      'playlists': [
        {'id': 7},
        {'id': 'x', 'name': 'bad'},
        'garbage',
        {'name': 'no id'},
      ],
    });
    expect(decoded, hasLength(1));
    expect(decoded.single.id, 7);
    expect(decoded.single.name, '');
    expect(decoded.single.isFavorites, isFalse);
    expect(decoded.single.trackIds, isEmpty);
    expect(decoded.single.createdAt.millisecondsSinceEpoch, 0);
  });

  test('空 / 缺 playlists 欄位 → 空清單', () {
    expect(PlaylistsBackup.decodePlaylists({}), isEmpty);
    expect(PlaylistsBackup.decodePlaylists({'playlists': null}), isEmpty);
  });
}
