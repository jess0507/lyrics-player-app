import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/library/models/library_section.dart';
import 'package:seek_player/features/library/providers/library_section_controller.dart';
import 'package:seek_player/features/library/widgets/library_section_chips.dart';
import 'package:seek_player/features/playlists/local_music_playlist_page.dart';
import 'package:seek_player/features/playlists/playlists_page.dart';

/// 「媒體庫」分頁:合併本地音樂與播放清單,由頂欄下方的 tag 切換。
///
/// 兩個區塊各自保有 Scaffold(搜尋頂欄、FAB 等),放在 [IndexedStack] 中
/// 切換時保留捲動位置、資料夾篩選等狀態;非作用區塊的 TickerMode 為關,
/// 本地音樂的返回鍵處理依此判斷是否可見。
/// 選中的區塊由 [librarySectionProvider] 持久化,下次開啟沿用。
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(librarySectionProvider);
    final chips = LibrarySectionChips(
      selected: section,
      onSelected: ref.read(librarySectionProvider.notifier).select,
    );
    return IndexedStack(
      index: section.index,
      children: [
        for (final section in LibrarySection.values)
          switch (section) {
            LibrarySection.localMusic => LocalMusicPlaylistPage(header: chips),
            LibrarySection.playlists => PlaylistsPage(header: chips),
          },
      ],
    );
  }
}
