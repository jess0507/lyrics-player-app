import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/playlists/models/playlist_entity.dart';

/// 清單顯示名稱:我的最愛 / 最近播放永遠顯示在地化字串(忽略 DB 內存的
/// fallback 名),其餘用使用者命名。
String playlistDisplayName(PlaylistEntity playlist, AppLocalizations l10n) {
  if (playlist.isFavorites) return l10n.playlist_favorites;
  if (playlist.isRecentlyPlayed) return l10n.playlist_recently_played;
  return playlist.name;
}
