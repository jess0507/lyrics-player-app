import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/cover/providers/track_artwork_provider.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/gen/assets.gen.dart';

/// 工具編輯頁(歌詞 / 封面)頂部:置中的封面(自訂優先、退回內嵌、
/// 再退回佔位圖)加上標題與演出者。
class TrackEditorHeader extends ConsumerWidget {
  const TrackEditorHeader({
    super.key,
    required this.track,
    this.coverSize = 160,
  });

  final Track track;

  /// 封面邊長;封面編輯頁以封面為主角,給較大的尺寸。
  final double coverSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cover = ref.watch(trackArtworkProvider(track.id)).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: coverSize,
              child: cover != null
                  ? Image(image: cover, fit: BoxFit.cover)
                  : ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Center(
                        child: Assets.icon.music.svg(
                          width: 64,
                          height: 64,
                          colorFilter: ColorFilter.mode(
                            scheme.outline,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            track.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          if (track.artist != null) ...[
            const SizedBox(height: 4),
            Text(
              track.artist!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
