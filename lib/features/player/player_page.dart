import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/player/providers/playback_controller.dart';
import 'package:seek_player/features/player/widgets/lyrics_mode_menu.dart';
import 'package:seek_player/features/player/widgets/lyrics_view.dart';
import 'package:seek_player/features/player/widgets/player_artwork_panel.dart';
import 'package:seek_player/features/player/widgets/player_background.dart';
import 'package:seek_player/features/player/widgets/player_controls.dart';
import 'package:seek_player/features/player/widgets/secondary_controls.dart';
import 'package:seek_player/features/player/widgets/seek_bar.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/models/player_default_tab.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';
import 'package:seek_player/shared/widgets/marquee_text.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // 確保背景統計 / 監聽器已啟動。
    ref.watch(playbackControllerProvider);
    final audio = ref.watch(audioPlayerServiceProvider);

    return _FrozenViewInsets(
      child: StreamBuilder<SequenceState?>(
        stream: audio.player.sequenceStateStream,
        builder: (context, snapshot) {
          final currentItem = snapshot.data?.currentSource?.tag;
          final mediaItem = currentItem is MediaItem ? currentItem : null;
          final hasTrack = mediaItem != null;

          final defaultTab = ref.watch(
            settingsControllerProvider.select((s) => s.playerDefaultTab),
          );
          final hasLyrics =
              hasTrack &&
              (ref
                      .watch(trackLyricsProvider(mediaItem.id))
                      .valueOrNull
                      ?.isNotEmpty ??
                  false);
          final showLyrics =
              hasTrack &&
              defaultTab == PlayerDefaultTab.fullScreenLyrics &&
              hasLyrics;

          final title = mediaItem?.title ?? l10n.player_nothing_playing;
          final artist = mediaItem?.artist ?? '';

          return PlayerBackground(
            trackId: mediaItem?.id,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                centerTitle: true,
                // 左上往下的箭頭：點擊收回成 mini player。
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // 標題顯示目前曲名 / 檔名與演出者，過長時跑馬燈滾動。
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MarqueeText(
                      title,
                      style:
                          Theme.of(context).appBarTheme.titleTextStyle ??
                          Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (artist.isNotEmpty)
                      Text(
                        artist,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                // 歌詞模式下,操作選單(含次控制列功能與關閉歌詞)移到右上角。
                actions: [
                  if (showLyrics)
                    LyricsModeMenu(
                      audio: audio,
                      trackId: mediaItem.id,
                      title: mediaItem.title,
                    ),
                ],
              ),
              // 頂部由 AppBar 處理;
              // 底部 / 左右系統列留白交給 SafeArea(top: false)。
              body: SafeArea(
                top: false,
                child: showLyrics
                    ? _LyricsLayout(
                        audio: audio,
                        trackId: mediaItem.id,
                        title: mediaItem.title,
                      )
                    : _PlayerLayout(
                        audio: audio,
                        hasTrack: hasTrack,
                        trackId: mediaItem?.id,
                        title: mediaItem?.title,
                        initialTab: defaultTab,
                        onShowLyrics: hasTrack
                            ? () => ref
                                  .read(settingsControllerProvider.notifier)
                                  .setPlayerDefaultTab(
                                    PlayerDefaultTab.fullScreenLyrics,
                                  )
                            : null,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 把 viewInsets 凍結為零:鍵盤只服務覆蓋其上的 bottom sheet(線上搜尋
/// 歌詞),播放頁子樹用不到鍵盤 inset。抽成獨立 widget 讓 MediaQuery 依賴
/// 止於此層——鍵盤動畫期間只有本 widget 重建;[child] 是同一個實例、提供
/// 的 data 值也不變,整個播放頁子樹(AppBar / 封面 / 控制列)維持靜止,
/// 不會每 frame 重建。
class _FrozenViewInsets extends StatelessWidget {
  const _FrozenViewInsets({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: child,
    );
  }
}

/// 一般播放版面:封面 / 歌詞 PageView、次控制列、進度條、主控制列。
/// 持有封面面板的 [PageController],讓次控制列的歌詞按鈕也能切到歌詞頁;
/// 起始頁由 [initialTab] 決定(內嵌歌詞分頁 → 第二頁,其餘 → 封面)。
class _PlayerLayout extends StatefulWidget {
  const _PlayerLayout({
    required this.audio,
    required this.hasTrack,
    required this.trackId,
    required this.title,
    required this.initialTab,
    required this.onShowLyrics,
  });

  final AudioPlayerService audio;
  final bool hasTrack;
  final String? trackId;
  final String? title;
  final PlayerDefaultTab initialTab;
  final VoidCallback? onShowLyrics;

  @override
  State<_PlayerLayout> createState() => _PlayerLayoutState();
}

class _PlayerLayoutState extends State<_PlayerLayout> {
  late final _pageController = PageController(
    initialPage: widget.initialTab == PlayerDefaultTab.embeddedLyrics ? 1 : 0,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: PlayerArtworkPanel(
            active: widget.hasTrack,
            controller: _pageController,
            trackId: widget.trackId,
            title: widget.title,
            onShowLyrics: widget.onShowLyrics,
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SeekBar(audio: widget.audio, enabled: widget.hasTrack),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: PlayerControls(audio: widget.audio, enabled: widget.hasTrack),
        ),
        SecondaryControls(
          audio: widget.audio,
          enabled: widget.hasTrack,
          trackId: widget.trackId,
          title: widget.title,
        ),
      ],
    );
  }
}

/// 歌詞滿版版面:上方歌詞佔滿剩餘空間,底部僅保留進度條與主控制列。
class _LyricsLayout extends StatelessWidget {
  const _LyricsLayout({
    required this.audio,
    required this.trackId,
    required this.title,
  });

  final AudioPlayerService audio;
  final String trackId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LyricsView(trackId: trackId, title: title),
        ),
        const SizedBox(height: 16),
        SeekBar(audio: audio, enabled: true),
        const SizedBox(height: 4),
        PlayerControls(audio: audio, enabled: true),
        const SizedBox(height: 12),
      ],
    );
  }
}
