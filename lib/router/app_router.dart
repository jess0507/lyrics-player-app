import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/features/playlists/local_music_playlist_page.dart';
import 'package:seek_player/features/playlists/playlist_detail_page.dart';
import 'package:seek_player/features/playlists/playlist_search_page.dart';
import 'package:seek_player/features/playlists/playlists_page.dart';
import 'package:seek_player/features/profile/about/about_page.dart';
import 'package:seek_player/features/profile/account/account_page.dart';
import 'package:seek_player/features/profile/profile_page.dart';
import 'package:seek_player/features/profile/settings/language_page.dart';
import 'package:seek_player/features/profile/settings/settings_page.dart';
import 'package:seek_player/features/profile/statistics/statistics_page.dart';
import 'package:seek_player/shared/widgets/scaffold_with_nav.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 由右往左滑入的轉場頁(播放清單搜尋頁共用)。
CustomTransitionPage<void> _slideInPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: animation.drive(
            Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/playlists',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNav(navigationShell: navigationShell),
        branches: [
          // StatefulShellBranch(
          //   routes: [
          //     GoRoute(
          //       path: '/music',
          //       builder: (context, state) => const MusicListPage(),
          //     ),
          //   ],
          // ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playlists',
                builder: (context, state) => const PlaylistsPage(),
                routes: [
                  // 「本地音樂」虛擬清單無 int id,須排在 ':id' 之前,
                  // 否則會被 ':id' 吃掉並在 int.parse 時丟例外。
                  GoRoute(
                    path: 'local',
                    builder: (context, state) => const LocalMusicPlaylistPage(),
                    routes: [
                      GoRoute(
                        path: 'search',
                        pageBuilder: (context, state) => _slideInPage(
                          key: state.pageKey,
                          // playlistId 為 null 代表「本地音樂」虛擬清單。
                          child: const PlaylistSearchPage(playlistId: null),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PlaylistDetailPage(
                      playlistId: int.parse(state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'search',
                        pageBuilder: (context, state) => _slideInPage(
                          key: state.pageKey,
                          child: PlaylistSearchPage(
                            playlistId: int.parse(state.pathParameters['id']!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'account',
                    builder: (context, state) => const AccountPage(),
                  ),
                  GoRoute(
                    path: 'statistics',
                    builder: (context, state) => const StatisticsPage(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsPage(),
                    routes: [
                      GoRoute(
                        path: 'language',
                        builder: (context, state) => const LanguagePage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
