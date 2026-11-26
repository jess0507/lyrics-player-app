import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/features/output/models/output_collection.dart';
import 'package:seek_player/features/output/providers/output_lyrics_tracks_provider.dart';
import 'package:seek_player/features/output/providers/output_task_items_provider.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具頁下半部的「產出」區:列出各種產出集合(任務、歌詞),
/// 點選進入該集合的曲目清單。產出都由上方的工具產生,所以與工具同頁。
class OutputCollectionsSection extends ConsumerWidget {
  const OutputCollectionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final counts = {
      OutputCollection.tasks: ref.watch(outputTaskItemsProvider).length,
      OutputCollection.lyrics: ref.watch(outputLyricsTracksProvider).length,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.output_section,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final collection in OutputCollection.values)
          ListTile(
            minTileHeight: 60,
            leading: CircleAvatar(child: collection.icon),
            title: Text(collection.label(l10n)),
            // 與播放清單列表一致:沒有曲目時不顯示曲數,但維持雙行版面。
            subtitle: counts[collection]! > 0
                ? Text(l10n.playlist_track_count(counts[collection]!))
                : const SizedBox.shrink(),
            onTap: () => context.push('/tools/output/${collection.name}'),
          ),
      ],
    );
  }
}
