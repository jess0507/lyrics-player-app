import 'package:flutter/material.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/tools/models/track_file_stat.dart';
import 'package:seek_player/shared/format.dart';
import 'package:seek_player/shared/widgets/track_leading.dart';

/// 工具選曲頁的曲目列:封面 + 標題(最多兩行)+「時長 | 大小 | 格式」。
class TrackPickerTile extends StatelessWidget {
  const TrackPickerTile({
    super.key,
    required this.track,
    required this.stat,
    required this.audio,
    required this.onTap,
  });

  final Track track;
  final TrackFileStat? stat;
  final AudioPlayerService audio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      if (track.duration != null) formatDuration(track.duration!),
      if (stat != null) _formatSize(stat!.sizeBytes),
      ?_extensionOf(track.filePath),
    ].join('  |  ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: TrackLeading(
        trackId: track.id,
        isCurrent: false,
        audio: audio,
        color: theme.colorScheme.primary,
      ),
      title: Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: meta.isEmpty
          ? null
          : Text(
              meta,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: onTap,
    );
  }
}

/// 以 1024 進位顯示,保留兩位小數(例 `5.73 MB`、`826.57 KB`)。
String _formatSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(2)} ${units[unit]}';
}

/// 取副檔名轉大寫(例 `MP3`);沒有副檔名回 null。
String? _extensionOf(String path) {
  final name = path.substring(path.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  return dot <= 0 || dot == name.length - 1
      ? null
      : name.substring(dot + 1).toUpperCase();
}
