import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../lyrics/background/lyrics_background_running.dart';
import '../../lyrics/providers/lyrics_pending_sync_store.dart';
import '../../lyrics/providers/track_lyrics_provider.dart';
import 'lyrics_menu_action.dart';

/// 歌詞按鈕點擊後的底部表單:依目前歌詞狀態列出 [lyricsMenuActions]
/// (自動產生 / 匯入 / 自動對時 / 字體大小 / 重新匯入 / 刪除)。
///
/// 後續動作以呼叫端的 [context]/[ref] 執行,避免本表單關閉後沿用已失效的 context。
void showLyricsActionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String title,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _LyricsActionsSheet(
      parentContext: context,
      parentRef: ref,
      trackId: trackId,
      title: title,
    ),
  );
}

class _LyricsActionsSheet extends ConsumerWidget {
  const _LyricsActionsSheet({
    required this.parentContext,
    required this.parentRef,
    required this.trackId,
    required this.title,
  });

  /// 呼叫端(控制列)的 context 與 ref,用來執行後續動作,生命週期不隨本表單結束。
  final BuildContext parentContext;
  final WidgetRef parentRef;

  final String trackId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final lyrics = ref.watch(trackLyricsProvider(trackId)).valueOrNull;
    final hasLyrics = lyrics != null && lyrics.isNotEmpty;
    // 產生是「從音訊辨識歌詞」:只在完全沒有歌詞時提供(與對時互補)。
    final canAutoGenerate = !hasLyrics;
    // 此表單一律提供 align:只要有歌詞就能對時 / 重新對時(已同步者亦可)。
    final canAutoSync = hasLyrics && !lyrics.synced;
    final actions = lyricsMenuActions(
      canAutoGenerate: canAutoGenerate,
      canAutoSync: canAutoSync,
      hasLyrics: hasLyrics,
    );
    // 背景任務一次只跑一件:只有選單會顯示自動產生/對時時才需要檢查是否
    // 已有其他工作在跑(前景服務執行中,或已送出、雲端還沒回終態),
    // 執行中時停用這些項目(變淺不可點)。
    final busy = (canAutoGenerate || canAutoSync)
        ? ref.watch(lyricsBackgroundRunningProvider) ||
              ref.watch(lyricsPendingSyncStoreProvider).isNotEmpty
        : false;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                Navigator.of(context).pop();
                runLyricsMenuAction(
                  parentContext,
                  parentRef,
                  action,
                  trackId: trackId,
                  title: title,
                );
              },
            ),
        ],
      ),
    );
  }
}
