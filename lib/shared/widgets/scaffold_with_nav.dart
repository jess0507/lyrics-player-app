import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/features/mini_player/mini_player.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 三大主頁面的底部導覽容器（使用 go_router 的 StatefulShell 維持各分頁狀態）。
class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: navigationShell,
      // 底部導覽不含播放器；mini player 疊在導覽列上方。
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            // 比 M3 預設(80)窄一點。
            height: 58,
            selectedIndex: navigationShell.currentIndex,
            // 點擊任一 tab 都回到該分支根頁(不還原上次停留的子頁)。
            onDestinationSelected: (index) =>
                navigationShell.goBranch(index, initialLocation: true),
            destinations: [
              // NavigationDestination(
              //   icon: const Icon(Icons.library_music_outlined),
              //   selectedIcon: const Icon(Icons.library_music),
              //   label: l10n.tab_music_list,
              // ),
              NavigationDestination(
                icon: const Icon(Icons.queue_music_outlined),
                selectedIcon: const Icon(Icons.queue_music),
                label: l10n.tab_playlists,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: l10n.tab_profile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
