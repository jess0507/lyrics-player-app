import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/features/output/providers/output_lyrics_tracks_provider.dart';
import 'package:seek_player/features/output/widgets/output_track_list.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 「Output → 歌詞」:列出有歌詞的曲目,點選播放並顯示滿版歌詞。
class OutputLyricsPage extends ConsumerWidget {
  const OutputLyricsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tracks = ref.watch(outputLyricsTracksProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.output_lyrics)),
      body: tracks.isEmpty
          ? Center(child: Text(l10n.output_lyrics_empty))
          : OutputTrackList(
              tracks: tracks,
              source: AnalyticsSource.outputLyrics,
            ),
    );
  }
}
