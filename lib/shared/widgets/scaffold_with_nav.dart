import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/features/mini_player/mini_player.dart';
import 'package:seek_player/gen/assets.gen.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/svg_icon.dart';

/// 各主分頁的底部導覽容器（使用 go_router 的 StatefulShell 維持各分頁狀態）。
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
            // 比 M3 預設(80)窄一點;label 已無 top padding,可再壓低。
            height: 54,
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
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: l10n.tab_tools,
              ),
              // SVG 沒有實心版,選中與否共用同一張,顏色由導覽列的 IconTheme 切換。
              NavigationDestination(
                icon: SvgIcon(Assets.icon.music),
                label: l10n.playlist_local_music,
              ),
              // 播放清單用 app logo 的形狀;SVG 經 SvgIcon 單色化,隨 IconTheme 換色。
              NavigationDestination(
                icon: SvgIcon(Assets.icon.appLogoSvg),
                label: l10n.tab_playlists,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                label: l10n.tab_profile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
