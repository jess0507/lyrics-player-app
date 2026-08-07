import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/shared/widgets/marquee_text.dart';

import '../../core/audio/audio_player_service.dart';
import '../cover/providers/track_artwork_provider.dart';
import '../player/providers/playback_controller.dart';
import '../player/providers/player_sheet_controller.dart';
import 'widgets/mini_play_pause_button.dart';
import 'widgets/mini_progress_bar.dart';
import 'widgets/swipe_track_area.dart';

/// 顯示於底部導覽列上方的迷你播放器。
///
/// 有正在播放的曲目時才顯示，呈現曲名與上一首 / 播放暫停 / 下一首按鈕；
/// 點擊本體（按鈕以外區域）會以 modal sheet 往上展開全螢幕播放器。
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 確保背景統計 / 監聽器已啟動（與全螢幕播放器共用同一個 controller）。
    ref.watch(playbackControllerProvider);
    final audio = ref.watch(audioPlayerServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<SequenceState?>(
      stream: audio.player.sequenceStateStream,
      builder: (context, snapshot) {
        final currentItem = snapshot.data?.currentSource?.tag;
        if (currentItem is! MediaItem) return const SizedBox.shrink();

        final title = currentItem.title;
        final artist = currentItem.artist ?? '';
        final cover = ref
            .watch(trackArtworkProvider(currentItem.id))
            .valueOrNull;

        return Padding(
          // 與左右兩側、下方導覽列保持距離,呈現漂浮卡片效果。
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: Material(
            color: scheme.surfaceContainerHighest,
            elevation: 1,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            // 整個 mini player 點擊都展開全螢幕播放器；
            // IconButton 會自行攔截點擊，只觸發各自的播放控制事件。
            child: InkWell(
              onTap: () => ref
                  .read(playerSheetControllerProvider.notifier)
                  .open(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiniProgressBar(audio: audio),
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        if (cover != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image(
                              image: cover,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else
                          SizedBox.shrink(),
                        Expanded(
                          // 曲名 / 歌手區左右滑動切換上 / 下一首（帶跟手位移效果）；
                          // 點擊（無水平位移）仍由外層 InkWell 展開播放器。
                          child: SwipeTrackArea(
                            onPrevious: audio.seekToPrevious,
                            onNext: audio.seekToNext,
                            child: Column(
                              // SwipeTrackArea 已撐滿列高，文字維持垂直置中。
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarqueeText(
                                  title,
                                  textAlign: TextAlign.start,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.primary,
                                      ),
                                ),
                                if (artist.isNotEmpty)
                                  Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: scheme.outline),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        MiniPlayPauseButton(audio: audio),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
