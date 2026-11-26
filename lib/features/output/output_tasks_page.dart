import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_protocol.dart';
import 'package:seek_player/features/output/providers/output_task_items_provider.dart';
import 'package:seek_player/features/output/widgets/output_track_list.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「Output → 任務」:列出進行中的歌詞任務(AI 產生 / 對時),
/// 點選播放並開播放頁(歌詞區顯示任務進度,完成後即為歌詞)。
class OutputTasksPage extends ConsumerWidget {
  const OutputTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(outputTaskItemsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.output_tasks)),
      body: items.isEmpty
          ? Center(child: Text(l10n.output_tasks_empty))
          : OutputTrackList(
              tracks: [for (final item in items) item.track],
              source: AnalyticsSource.outputTasks,
              trailingBuilder: (context, index) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(
                  switch (items[index].job.mode) {
                    LyricsBackgroundMode.generate => l10n.output_task_generate,
                    LyricsBackgroundMode.align => l10n.output_task_align,
                  },
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
    );
  }
}
