import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../../features/lyrics/models/lyrics_entity.dart';
import '../../features/cover/models/track_cover_entity.dart';
import '../../features/playlists/models/playlist_entity.dart';
import '../../features/profile/statistics/models/daily_track_stat_entity.dart';
import '../sync/sync_state_store.dart';
import 'preferences_service.dart';

const _kCleanupDoneKey = 'trackId_cleanup_v1_done';

/// trackId 指紋化(sync v5,見 [LyricsEntity])之前的舊資料是
/// on_audio_query 的 MediaStore 數字 id;合法指紋固定為 40 碼 sha1 hex。
final _hashTrackIdPattern = RegExp(r'^[0-9a-f]{40}$');

/// 一次性清掉 trackId 非 sha1 hash 格式的舊資料。只跑一次,靠
/// [PreferencesService] 的 flag 擋住之後每次啟動重複執行。
Future<void> cleanupNonHashTrackIds({
  required Isar isar,
  required PreferencesService prefs,
  required SyncStateStore syncState,
}) async {
  if (prefs.getBool(_kCleanupDoneKey) ?? false) return;

  final invalidLyricsIds = [
    for (final e in isar.lyricsEntitys.where().findAllSync())
      if (!_hashTrackIdPattern.hasMatch(e.trackId)) e.id,
  ];
  if (invalidLyricsIds.isNotEmpty) {
    await isar.writeTxn(() => isar.lyricsEntitys.deleteAll(invalidLyricsIds));
    syncState.markLyricsModified();
  }

  final invalidCoverIds = [
    for (final e in isar.trackCoverEntitys.where().findAllSync())
      if (!_hashTrackIdPattern.hasMatch(e.trackId)) e.id,
  ];
  if (invalidCoverIds.isNotEmpty) {
    await isar.writeTxn(
      () => isar.trackCoverEntitys.deleteAll(invalidCoverIds),
    );
  }

  final invalidStatIds = [
    for (final e in isar.dailyTrackStatEntitys.where().findAllSync())
      if (!_hashTrackIdPattern.hasMatch(e.trackId)) e.id,
  ];
  if (invalidStatIds.isNotEmpty) {
    await isar.writeTxn(
      () => isar.dailyTrackStatEntitys.deleteAll(invalidStatIds),
    );
    syncState.markModified();
  }

  var removedPlaylistEntries = 0;
  for (final pl in isar.playlistEntitys.where().findAllSync()) {
    final filtered = pl.trackIds.where(_hashTrackIdPattern.hasMatch).toList();
    if (filtered.length == pl.trackIds.length) continue;
    removedPlaylistEntries += pl.trackIds.length - filtered.length;
    pl.trackIds = filtered;
    await isar.writeTxn(() => isar.playlistEntitys.put(pl));
  }
  if (removedPlaylistEntries > 0) syncState.markPlaylistModified();

  debugPrint(
    'trackId cleanup: lyrics=${invalidLyricsIds.length}, '
    'covers=${invalidCoverIds.length}, stats=${invalidStatIds.length}, '
    'playlistEntries=$removedPlaylistEntries',
  );

  await prefs.setBool(_kCleanupDoneKey, true);
}
