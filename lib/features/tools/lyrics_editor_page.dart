import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_active_job_provider.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/music_list/models/track.dart';
import 'package:seek_player/features/player/providers/lyrics_text_align_controller.dart';
import 'package:seek_player/features/player/widgets/lyrics_action_tiles.dart';
import 'package:seek_player/features/tools/widgets/lyrics_job_progress_card.dart';
import 'package:seek_player/features/tools/widgets/track_editor_header.dart';
import 'package:seek_player/features/tools/widgets/track_editor_scaffold.dart';
import 'package:seek_player/l10n/app_localizations.dart';

/// 工具「製作歌詞」選完曲目後的編輯頁:上方封面與標題,有長時間任務
/// (自動產生 / 對時)時顯示進度卡,接著是歌詞動作與目前歌詞預覽。
class LyricsEditorPage extends StatelessWidget {
  const LyricsEditorPage({super.key, required this.trackId, this.initialTrack});

  final String trackId;
  final Track? initialTrack;

  @override
  Widget build(BuildContext context) {
    return TrackEditorScaffold(
      title: AppLocalizations.of(context)!.tools_lyrics,
      trackId: trackId,
      initialTrack: initialTrack,
      builder: (context, track) => _LyricsEditorBody(track: track),
    );
  }
}

class _LyricsEditorBody extends ConsumerWidget {
  const _LyricsEditorBody({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final activeJob = ref.watch(lyricsActiveJobProvider(track.id));
    final lyrics = ref.watch(trackLyricsProvider(track.id)).valueOrNull;
    final align = ref.watch(lyricsTextAlignProvider).textAlign;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        TrackEditorHeader(track: track),
        if (activeJob) LyricsJobProgressCard(trackId: track.id),
        LyricsActionTiles(
          actionContext: context,
          actionRef: ref,
          trackId: track.id,
          title: track.title,
          // 進度卡已有取消鈕。
          showCancel: false,
          // 字體大小 / 對齊方式改由播放頁「更多」選單設定。
          showDisplayOptions: false,
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.tools_lyrics_preview,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (lyrics == null || lyrics.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.lyrics_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          for (final line in lyrics.lines)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              // 空行保留為段落間距。
              child: Text(
                line.text.isEmpty ? ' ' : line.text,
                textAlign: align,
                style: theme.textTheme.bodyLarge,
              ),
            ),
      ],
    );
  }
}
