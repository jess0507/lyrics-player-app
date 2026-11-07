import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/cover/providers/track_artwork_provider.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/player/widgets/lyrics_view.dart';
import 'package:seek_player/features/player/widgets/player_artwork.dart';

/// 播放頁中央視覺區:水平 PageView,第一頁專輯封面、第二頁歌詞容器,
/// 左右滑動切換。歌詞頁已有歌詞時右上角提供進入滿版歌詞的按鈕
/// ([onShowLyrics]),否則由 [LyricsView] 顯示匯入提示。滿版歌詞本身由
/// [PlayerPage] 在滿版模式下呈現。[controller] 由父層持有,讓次控制列的
/// 歌詞按鈕也能切到歌詞頁。
class PlayerArtworkPanel extends StatelessWidget {
  const PlayerArtworkPanel({
    super.key,
    required this.active,
    required this.controller,
    this.trackId,
    this.title,
    this.onShowLyrics,
  });

  final bool active;
  final PageController controller;
  final String? trackId;
  final String? title;
  final VoidCallback? onShowLyrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PageView(
              controller: controller,
              children: [
                _ArtworkPage(active: active, trackId: trackId),
                _LyricsPage(
                  trackId: trackId,
                  title: title,
                  onShowLyrics: onShowLyrics,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PageIndicator(controller: controller, count: 2),
      ],
    );
  }
}

/// PageView 底下的翻頁提示:每頁一條短線,目前頁高亮。
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.controller, required this.count});

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients && controller.page != null
            ? controller.page!.round()
            : controller.initialPage;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final active = i == page;
            return Container(
              width: 16,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: active ? scheme.primary : scheme.outlineVariant,
              ),
            );
          }),
        );
      },
    );
  }
}

/// PageView 第一頁:有封面(自訂優先,退回音檔內嵌)顯示圖片,否則佔位圖。
/// 封面編輯已移至次控制列「更多」選單([_PlayerMenuAction])。
class _ArtworkPage extends ConsumerWidget {
  const _ArtworkPage({required this.active, required this.trackId});

  final bool active;
  final String? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final id = trackId;
    final artwork = id == null
        ? null
        : ref.watch(trackArtworkProvider(id)).valueOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: scheme.surfaceContainerHighest),
        ),
        Positioned.fill(
          child: artwork != null
              ? Image(image: artwork, fit: BoxFit.cover)
              : PlayerArtwork(active: active),
        ),
      ],
    );
  }
}

/// PageView 第二頁:內嵌歌詞;有歌詞時右上角提供滿版入口,無歌詞時
/// [LyricsView] 自身顯示匯入提示。無曲目時僅顯示底色佔位。
class _LyricsPage extends ConsumerWidget {
  const _LyricsPage({
    required this.trackId,
    required this.title,
    required this.onShowLyrics,
  });

  final String? trackId;
  final String? title;
  final VoidCallback? onShowLyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final id = trackId;
    if (id == null) {
      return ColoredBox(color: scheme.surfaceContainerHighest);
    }
    final l10n = AppLocalizations.of(context)!;
    final lyrics = ref.watch(trackLyricsProvider(id)).valueOrNull;
    final hasLyrics = lyrics != null && lyrics.isNotEmpty;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: LyricsView(trackId: id, title: title ?? ''),
          ),
        ),
        if (hasLyrics && onShowLyrics != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: l10n.lyrics_show,
              icon: const Icon(Icons.fullscreen),
              onPressed: onShowLyrics,
            ),
          ),
      ],
    );
  }
}
