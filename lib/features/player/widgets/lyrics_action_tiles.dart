import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_running.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_active_job_provider.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_store.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/player/widgets/lyrics_cancel_job_action.dart';
import 'package:seek_player/features/player/widgets/lyrics_menu_action.dart';

/// 依目前歌詞狀態列出 [lyricsMenuActions] 的 ListTile 群組,
/// 供歌詞動作表單與工具的歌詞編輯頁共用。
///
/// 動作以 [actionContext]/[actionRef] 執行(表單關閉後仍有效的呼叫端 context);
/// 點選時先呼叫 [onSelected](例如表單用來關閉自己)再執行動作。
/// [showCancel] 為 false 時不列「取消」(呼叫端另有取消入口)。
class LyricsActionTiles extends ConsumerWidget {
  const LyricsActionTiles({
    super.key,
    required this.actionContext,
    required this.actionRef,
    required this.trackId,
    required this.title,
    this.onSelected,
    this.showCancel = true,
  });

  final BuildContext actionContext;
  final WidgetRef actionRef;
  final String trackId;
  final String title;
  final VoidCallback? onSelected;
  final bool showCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final lyrics = ref.watch(trackLyricsProvider(trackId)).valueOrNull;
    final hasLyrics = lyrics != null && lyrics.isNotEmpty;
    // 產生是「從音訊辨識歌詞」:只在完全沒有歌詞時提供(與對時互補)。
    final canAiGenerate = !hasLyrics;
    // 此表單一律提供 align:只要有歌詞就能對時 / 重新對時(已同步者亦可)。
    final canAutoSync = hasLyrics && !lyrics.synced;
    final actions = lyricsMenuActions(
      canAiGenerate: canAiGenerate,
      canAutoSync: canAutoSync,
      hasLyrics: hasLyrics,
    );
    // 背景任務一次只跑一件:只有選單會顯示自動產生/對時時才需要檢查是否
    // 已有其他工作在跑(前景服務執行中,或已送出、雲端還沒回終態),
    // 執行中時停用這些項目(變淺不可點)。
    final busy = (canAiGenerate || canAutoSync)
        ? ref.watch(lyricsBackgroundRunningProvider) ||
              ref.watch(lyricsPendingSyncStoreProvider).isNotEmpty
        : false;
    // 這首歌自己有工作在跑(而非別首歌佔線)時,最上面加取消,
    // 不必特地切去滿版歌詞頁才能取消。
    final ownJobActive =
        showCancel && ref.watch(lyricsActiveJobProvider(trackId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ownJobActive)
          ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: Text(l10n.common_cancel),
            onTap: () {
              onSelected?.call();
              cancelLyricsJob(actionContext, actionRef, trackId: trackId);
            },
          ),
        for (final action in actions)
          ListTile(
            enabled: !(busy && action.usesBackgroundTask),
            leading: Icon(action.icon),
            title: Text(
              busy && action.usesBackgroundTask
                  ? '${action.label(l10n)}${l10n.lyrics_action_running_suffix}'
                  : action.label(l10n),
            ),
            onTap: () {
              onSelected?.call();
              runLyricsMenuAction(
                actionContext,
                actionRef,
                action,
                trackId: trackId,
                title: title,
              );
            },
          ),
      ],
    );
  }
}
