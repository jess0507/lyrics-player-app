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
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/tools/cover_editor_page.dart';
import 'package:seek_player/features/tools/lyrics_editor_page.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';
import 'package:seek_player/features/tools/tool_track_picker_page.dart';
import 'package:seek_player/features/tools/tools_page.dart';
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
    initialLocation: '/local',
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
          // 「工具」分頁:先選工具,再進選曲頁對單首曲目執行。
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tools',
                builder: (context, state) => const ToolsPage(),
                routes: [
                  // 選曲頁與編輯頁全螢幕顯示:掛在 root navigator,
                  // 蓋過 shell 的底部導覽列。
                  GoRoute(
                    path: ':tool',
                    parentNavigatorKey: rootNavigatorKey,
                    // 未知的工具名稱退回工具頁。
                    redirect: (context, state) =>
                        ToolKind.fromName(state.pathParameters['tool']) == null
                        ? '/tools'
                        : null,
                    builder: (context, state) => ToolTrackPickerPage(
                      tool: ToolKind.fromName(state.pathParameters['tool'])!,
                    ),
                    routes: [
                      // 選完曲目後依工具進對應的編輯頁(歌詞 / 封面)。
                      GoRoute(
                        path: ':trackId',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final trackId = state.pathParameters['trackId']!;
                          final track = state.extra as Track?;
                          return switch (ToolKind.fromName(
                            state.pathParameters['tool'],
                          )!) {
                            ToolKind.lyrics => LyricsEditorPage(
                              trackId: trackId,
                              initialTrack: track,
                            ),
                            ToolKind.cover => CoverEditorPage(
                              trackId: trackId,
                              initialTrack: track,
                            ),
                          };
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 「本地音樂」分頁。
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/local',
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playlists',
                builder: (context, state) => const PlaylistsPage(),
                routes: [
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
                // 子頁全螢幕顯示:掛在 root navigator,蓋過 shell 的底部導覽列。
                routes: [
                  GoRoute(
                    path: 'account',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AccountPage(),
                  ),
                  GoRoute(
                    path: 'statistics',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const StatisticsPage(),
                  ),
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const SettingsPage(),
                    routes: [
                      GoRoute(
                        path: 'language',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => const LanguagePage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'about',
                    parentNavigatorKey: rootNavigatorKey,
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
