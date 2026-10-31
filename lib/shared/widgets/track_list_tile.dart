import 'package:flutter/material.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/shared/widgets/playing_indicator.dart';
import 'package:seek_player/shared/widgets/track_leading.dart';

/// 曲目列表項:縮圖 + 標題(播放中時加上指示器與強調樣式)+ 歌手名，
/// trailing、onTap 與 onLongPress 交由呼叫端決定（音樂庫、播放清單各自有不同動作）。
class TrackListTile extends StatelessWidget {
  const TrackListTile({
    super.key,
    required this.track,
    required this.audio,
    this.isCurrent = false,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 4.0,
    ),
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final Track track;
  final AudioPlayerService audio;
  final bool isCurrent;
  final EdgeInsetsGeometry contentPadding;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: contentPadding,
      leading: TrackLeading(
        trackId: track.id,
        isCurrent: isCurrent,
        audio: audio,
        color: scheme.primary,
      ),
      title: Row(
        children: [
          if (isCurrent) ...[
            PlayingTrackLeading(audio: audio, color: scheme.primary),
            const SizedBox(width: 8),
          ],
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isCurrent
                  ? TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
          ),
        ],
      ),
      subtitle: track.artist == null ? null : Text(track.artist!, maxLines: 1),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
