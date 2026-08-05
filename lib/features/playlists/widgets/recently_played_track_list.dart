import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/audio/audio_player_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/track_list_tile.dart';
import '../../player/providers/playback_controller.dart';
import '../providers/recently_played_provider.dart';
import 'playlist_track_actions_sheet.dart';

/// 「最近播放」清單內容:依播放日期分組(今天 / 昨天 / 日期)。
/// 唯讀,不可拖曳排序;每首曲目可開啟操作選單(加入清單、檢視資訊),
/// 但不提供「從清單移除」,清除全部交由呼叫端(appbar 動作)處理。
class RecentlyPlayedTrackList extends ConsumerWidget {
  const RecentlyPlayedTrackList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(recentlyPlayedProvider);
    final audio = ref.watch(audioPlayerServiceProvider);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l10n.playlist_empty, textAlign: TextAlign.center),
        ),
      );
    }

    final locale = Localizations.localeOf(context).toString();
    final tracks = [for (final item in items) item.track];
    final rows = _buildRows(items, l10n, locale);

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.header case final header?) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(header, style: Theme.of(context).textTheme.titleSmall),
          );
        }
        final item = row.item!;
        return TrackListTile(
          key: ValueKey(item.track.id),
          track: item.track,
          audio: audio,
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () =>
                showPlaylistTrackActionsSheet(context, ref, item.track),
          ),
          onTap: () => ref
              .read(playbackControllerProvider)
              .playTracksAt(tracks, row.trackIndex),
        );
      },
    );
  }

  /// 將 [items] 依播放日期(年月日)分組,在每組第一筆前插入標題列。
  /// [items] 已依播放時間新到舊排序,同日項目必為連續,故只需單趟掃描。
  List<_Row> _buildRows(
    List<RecentlyPlayedItem> items,
    AppLocalizations l10n,
    String locale,
  ) {
    final rows = <_Row>[];
    DateTime? lastDay;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final day = DateTime(
        item.playedAt.year,
        item.playedAt.month,
        item.playedAt.day,
      );
      if (day != lastDay) {
        rows.add(_Row.header(_dateGroupLabel(day, l10n, locale)));
        lastDay = day;
      }
      rows.add(_Row.item(item, i));
    }
    return rows;
  }

  String _dateGroupLabel(DateTime day, AppLocalizations l10n, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.common_today;
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.common_yesterday;
    }
    return DateFormat.yMMMd(locale).format(day);
  }
}

/// 清單中的一列:日期標題或曲目項目(擇一)。[trackIndex] 為該曲目在
/// 扁平化 track 清單中的位置,供 [playTracksAt] 使用。
class _Row {
  const _Row.header(this.header) : item = null, trackIndex = -1;
  const _Row.item(RecentlyPlayedItem this.item, this.trackIndex) : header = null;

  final String? header;
  final RecentlyPlayedItem? item;
  final int trackIndex;
}
