import 'package:seek_player/l10n/app_localizations.dart';

/// 「媒體庫」分頁上方 tag 切換的區塊;宣告順序即顯示順序。
enum LibrarySection {
  localMusic,
  playlists;

  String label(AppLocalizations l10n) => switch (this) {
    localMusic => l10n.playlist_local_music,
    playlists => l10n.tab_playlists,
  };
}
