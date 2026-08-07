import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../lyrics/auto_sync/lyrics_auto_sync_service.dart';
import '../../lyrics/providers/track_lyrics_provider.dart';
import '../../lyrics/services/lyrics_repository.dart';
import 'lyrics_ai_generate_action.dart';
import 'lyrics_auto_sync_action.dart';
import 'lyrics_font_size_sheet.dart';
import 'lyrics_online_search_action.dart';
import 'lyrics_sign_in_gate.dart';
import 'lyrics_usage_limit_gate.dart';
import 'lyrics_view.dart';

/// 歌詞相關的選單動作,供「次控制列更多選單」與「歌詞滿版選單」共用。
/// 顯示與否由 [lyricsMenuActions] 依狀態決定,動作分派由 [runLyricsMenuAction] 處理。
enum LyricsMenuAction {
  /// AI 製作歌詞(WhisperX ASR);完全沒有歌詞時顯示。
  aiGenerate,

  /// 上網搜尋歌詞(LRCLIB);完全沒有歌詞時顯示(排在 [aiGenerate] 之後)。
  searchOnline,

  /// 手動匯入歌詞;完全沒有歌詞時顯示(排在 [searchOnline] 之後)。
  import,

  /// 自動對時(aeneas 引擎);已有純文字、尚未同步時顯示。
  autoSyncAeneas,

  /// 自動對時(WhisperX 引擎);已有純文字、尚未同步時顯示。
  autoSyncWhisperX,

  /// 字體大小;已有歌詞時顯示。
  fontSize,

  /// 重新匯入歌詞;已有歌詞時顯示。
  reimport,

  /// 刪除歌詞;已有歌詞時顯示。
  delete;

  IconData get icon => switch (this) {
    aiGenerate => Icons.lyrics_outlined,
    searchOnline => Icons.travel_explore_outlined,
    import => Icons.file_open_outlined,
    autoSyncAeneas => Icons.auto_fix_high,
    autoSyncWhisperX => Icons.auto_awesome,
    fontSize => Icons.text_fields,
    reimport => Icons.file_open_outlined,
    delete => Icons.delete_outline,
  };

  /// 是否為背景任務(前景服務,一次只跑一件):
  /// 背景執行中時,選單須停用這些項目避免重複觸發。
  bool get usesBackgroundTask => switch (this) {
    aiGenerate || autoSyncAeneas || autoSyncWhisperX => true,
    _ => false,
  };

  String label(AppLocalizations l10n) => switch (this) {
    aiGenerate => l10n.lyrics_ai_generate,
    searchOnline => l10n.lyrics_search_online,
    import => l10n.lyrics_import,
    autoSyncAeneas => '${l10n.lyrics_auto_sync} · aeneas',
    autoSyncWhisperX => '${l10n.lyrics_auto_sync} · WhisperX',
    fontSize => l10n.lyrics_font_size,
    reimport => l10n.lyrics_reimport,
    delete => l10n.lyrics_delete,
  };
}

/// 依目前歌詞狀態挑出要顯示的歌詞動作與順序。
/// [canAiGenerate] 為「完全沒有歌詞」(可從音訊直接產生);
/// [canAutoSync] 為「已有純文字、尚未同步」;[hasLyrics] 為「已有歌詞」。
List<LyricsMenuAction> lyricsMenuActions({
  required bool canAiGenerate,
  required bool canAutoSync,
  required bool hasLyrics,
}) {
  return [
    // 無歌詞時提供三種取得方式:自動產生、上網搜尋、手動匯入。
    if (canAiGenerate) LyricsMenuAction.aiGenerate,
    if (!hasLyrics) LyricsMenuAction.searchOnline,
    if (!hasLyrics) LyricsMenuAction.import,
    if (canAutoSync) ...[
      LyricsMenuAction.autoSyncAeneas,
      LyricsMenuAction.autoSyncWhisperX,
    ],
    if (hasLyrics) ...[
      LyricsMenuAction.fontSize,
      LyricsMenuAction.reimport,
      LyricsMenuAction.delete,
    ],
  ];
}

/// 執行歌詞選單動作。[onDeleted] 於成功刪除歌詞後呼叫(例如退回封面)。
Future<void> runLyricsMenuAction(
  BuildContext context,
  WidgetRef ref,
  LyricsMenuAction action, {
  required String trackId,
  required String title,
  VoidCallback? onDeleted,
}) async {
  // 自動產生 / 自動對時走雲端服務,需登入;未登入時先詢問並導向登入頁。
  if (action == LyricsMenuAction.aiGenerate ||
      action == LyricsMenuAction.autoSyncAeneas ||
      action == LyricsMenuAction.autoSyncWhisperX) {
    final l10n = AppLocalizations.of(context)!;
    final message = action == LyricsMenuAction.aiGenerate
        ? l10n.lyrics_ai_generate_need_login
        : l10n.lyrics_auto_sync_need_login;
    final signedIn = await ensureSignedInForLyrics(
      context,
      ref,
      message: message,
    );
    if (!signedIn || !context.mounted) return;

    // 登入後才檢查用量,避免未登入時誤讀 usage/{uid}。
    final withinLimit = await ensureWithinUsageLimitForLyrics(context, ref);
    if (!withinLimit || !context.mounted) return;
  }

  switch (action) {
    case LyricsMenuAction.autoSyncAeneas:
      await runLyricsAutoSync(
        context,
        ref,
        trackId: trackId,
        title: title,
        engine: LyricsAlignEngine.aeneas,
      );
    case LyricsMenuAction.autoSyncWhisperX:
      await runLyricsAutoSync(
        context,
        ref,
        trackId: trackId,
        title: title,
        engine: LyricsAlignEngine.whisperx,
      );
    case LyricsMenuAction.fontSize:
      showLyricsFontSizeSheet(context);
    case LyricsMenuAction.searchOnline:
      await runLyricsOnlineSearch(context, ref, trackId: trackId, title: title);
    case LyricsMenuAction.import:
    case LyricsMenuAction.reimport:
      await runLyricsImport(context, ref, trackId: trackId, title: title);
    case LyricsMenuAction.delete:
      await _confirmDelete(context, ref, trackId, onDeleted);
    case LyricsMenuAction.aiGenerate:
      await runLyricsAiGenerate(context, ref, trackId: trackId, title: title);
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String trackId,
  VoidCallback? onDeleted,
) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.lyrics_delete_confirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.common_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.common_delete),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await ref.read(lyricsRepositoryProvider).deleteByTrackId(trackId);
  ref.invalidate(trackLyricsProvider(trackId));
  onDeleted?.call();
}
