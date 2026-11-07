import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/cover/providers/track_artwork_provider.dart';
import 'package:seek_player/gen/assets.gen.dart';

/// 曲目清單每列的 leading:預設顯示曲目封面縮圖(自訂封面優先,無自訂時
/// 退回音檔內嵌封面),查無封面時退回 [Assets.icon.music] 佔位圖。
/// 供音樂清單與播放清單等各列共用。
class TrackLeading extends ConsumerWidget {
  const TrackLeading({
    super.key,
    required this.trackId,
    required this.isCurrent,
    required this.audio,
    required this.color,
  });

  final String trackId;
  final bool isCurrent;
  final AudioPlayerService audio;
  final Color color;

  static const double _size = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cover = ref.watch(trackArtworkProvider(trackId)).valueOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            cover != null
                ? Image(image: cover, fit: BoxFit.cover)
                : ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: Assets.icon.music.svg(
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          scheme.outline,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
