import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/player/widgets/lyrics_actions_sheet.dart';

import '../../../core/crash_reporter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../lyrics/providers/lyrics_active_job_provider.dart';
import '../../lyrics/providers/track_lyrics_provider.dart';
import '../../lyrics/services/lyrics_import_service.dart';
import '../providers/lyrics_font_scale_controller.dart';
import 'lyrics_job_status_view.dart';
import 'lyrics_synced_view.dart';
import 'lyrics_unsynced_view.dart';

/// 完整播放頁的歌詞視圖:依 [trackId] 取歌詞並分派 loading / 空狀態 /
/// synced(同步捲動)/ unsynced(靜態整篇),滿版顯示。歌詞操作選單移至
/// AppBar 的 [LyricsModeMenu]。mini player 不顯示歌詞,僅此處。
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key, required this.trackId, required this.title});

  final String trackId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeJob = ref.watch(lyricsActiveJobProvider(trackId));
    if (activeJob) {
      return LyricsJobStatusView(trackId: trackId);
    }

    final async = ref.watch(trackLyricsProvider(trackId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // 讀取失敗極少見,當作無歌詞處理,讓使用者可重新匯入。
      error: (_, _) => _EmptyLyrics(trackId: trackId, title: title),
      data: (lyrics) {
        if (lyrics == null || lyrics.isEmpty) {
          return _EmptyLyrics(trackId: trackId, title: title);
        }
        final scale = ref.watch(lyricsFontScaleProvider);
        return MediaQuery(
          // 僅縮放歌詞文字,不影響版面間距。
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: lyrics.synced
              ? LyricsSyncedView(lyrics: lyrics)
              : LyricsUnsyncedView(lyrics: lyrics),
        );
      },
    );
  }
}

/// 無歌詞空狀態:提示文字 + 匯入入口(呼叫匯入服務)。
class _EmptyLyrics extends ConsumerWidget {
  const _EmptyLyrics({required this.trackId, required this.title});

  final String trackId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lyrics_outlined, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            l10n.lyrics_empty,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showLyricsActionsSheet(
              context,
              ref,
              trackId: trackId,
              title: title,
            ),
            icon: const Icon(Icons.file_open_outlined),
            label: Text(l10n.lyrics_import),
          ),
        ],
      ),
    );
  }
}

/// 觸發匯入並以 toast 回報結果;取消選檔不提示。成功時匯入服務會
/// invalidate 對應的 [trackLyricsProvider],視圖自動重讀。空狀態與重新匯入共用。
Future<void> runLyricsImport(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final imported = await ref
        .read(lyricsImportServiceProvider)
        .importForTrack(trackId: trackId, title: title);
    if (!imported) return; // 使用者取消
    showAppToast(l10n.lyrics_import_success);
  } on LyricsImportException catch (e, s) {
    reportError(e, s, reason: '匯入歌詞失敗（${e.error.name}）');
    showAppToast(_importErrorText(l10n, e.error));
  }
}

String _importErrorText(AppLocalizations l10n, LyricsImportError error) =>
    switch (error) {
      LyricsImportError.tooLarge => l10n.lyrics_import_too_large,
      LyricsImportError.empty => l10n.lyrics_import_empty,
      LyricsImportError.unreadable => l10n.lyrics_import_failed,
    };
