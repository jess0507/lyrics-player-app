import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/network/ensure_online.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/features/lyrics/auto_align/lyrics_auto_align_service.dart';
import 'package:seek_player/features/lyrics/providers/track_lyrics_provider.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';
import 'package:seek_player/features/player/widgets/lyrics_ai_generate_action.dart';
import 'package:seek_player/features/player/widgets/lyrics_auto_align_action.dart';
import 'package:seek_player/features/player/widgets/lyrics_download_action.dart';
import 'package:seek_player/features/player/widgets/lyrics_font_size_sheet.dart';
import 'package:seek_player/features/player/widgets/lyrics_online_search_action.dart';
import 'package:seek_player/features/player/widgets/lyrics_edit_page.dart';
import 'package:seek_player/features/player/widgets/lyrics_sign_in_gate.dart';
import 'package:seek_player/features/player/widgets/lyrics_text_align_sheet.dart';
import 'package:seek_player/features/player/widgets/lyrics_usage_limit_gate.dart';
import 'package:seek_player/features/player/widgets/lyrics_view.dart';

/// 歌詞相關的選單動作,供「次控制列更多選單」與「歌詞滿版選單」共用。
/// 顯示與否由 [lyricsMenuActions] 依狀態決定,動作分派由 [runLyricsMenuAction] 處理。
enum LyricsMenuAction implements AnalyticsAction {
  /// AI 製作歌詞(WhisperX ASR);完全沒有歌詞時顯示。
  aiGenerate,

  /// 上網搜尋歌詞(LRCLIB);完全沒有歌詞時顯示(排在 [aiGenerate] 之後)。
  searchOnline,

  /// 編輯歌詞(文字框,可貼上或打字);無歌詞時排第二(在 [searchOnline] 之後),
  /// 已有歌詞時排在 [reimport] 之前(覆蓋現有歌詞)。
  edit,

  /// 從檔案匯入歌詞;完全沒有歌詞時顯示(排在 [edit] 之後)。
  import,

  /// 自動對時(WhisperX 引擎);已有歌詞時顯示,已同步者為重新同步。
  /// 歌曲對齊較準,排在 [autoAlignAeneas] 之前。
  autoAlignWhisperX,

  /// 自動對時(aeneas 引擎);已有歌詞時顯示,已同步者為重新同步。
  autoAlignAeneas,

  /// 字體大小;已有歌詞時顯示。
  fontSize,

  /// 對齊方式(左 / 中 / 右);已有歌詞時顯示(排在 [fontSize] 之後)。
  textAlign,

  /// 重新匯入歌詞;已有歌詞時顯示。
  reimport,

  /// 下載歌詞(匯出成檔案);已有歌詞時顯示。
  download,

  /// 刪除歌詞;已有歌詞時顯示。
  delete;

  IconData get icon => switch (this) {
    aiGenerate => Icons.lyrics_outlined,
    searchOnline => Icons.travel_explore_outlined,
    edit => Icons.content_paste,
    import => Icons.file_open_outlined,
    autoAlignAeneas => Icons.auto_fix_high,
    autoAlignWhisperX => Icons.auto_awesome,
    fontSize => Icons.text_fields,
    textAlign => Icons.format_align_left,
    reimport => Icons.file_open_outlined,
    download => Icons.download_outlined,
    delete => Icons.delete_outline,
  };

  /// 是否為背景任務(前景服務,一次只跑一件):
  /// 背景執行中時,選單須停用這些項目避免重複觸發。
  @override
  AnalyticsEvent get analyticsEvent => AnalyticsEvent.lyricsAction;

  bool get usesBackgroundTask => switch (this) {
    aiGenerate || autoAlignAeneas || autoAlignWhisperX => true,
    _ => false,
  };

  /// 是否需要網路連線(雲端服務 / 線上搜尋):
  /// 離線時點選只提示確認連線,不進入後續流程。
  bool get needsNetwork => switch (this) {
    aiGenerate ||
    searchOnline ||
    import ||
    autoAlignAeneas ||
    autoAlignWhisperX => true,
    _ => false,
  };

  /// [synced] 為目前歌詞已同步:對時項目改顯示「重新同步」。
  String label(AppLocalizations l10n, {bool synced = false}) => switch (this) {
    aiGenerate => l10n.lyrics_ai_generate,
    searchOnline => l10n.lyrics_search_online,
    edit => l10n.lyrics_edit,
    import => l10n.lyrics_import,
    autoAlignAeneas => '${_alignLabel(l10n, synced)} · aeneas',
    autoAlignWhisperX => '${_alignLabel(l10n, synced)} · WhisperX',
    fontSize => l10n.lyrics_font_size,
    textAlign => l10n.lyrics_text_align,
    reimport => l10n.lyrics_import,
    download => l10n.lyrics_download,
    delete => l10n.lyrics_delete,
  };
}

String _alignLabel(AppLocalizations l10n, bool synced) =>
    synced ? l10n.lyrics_auto_resync : l10n.lyrics_auto_align;

/// 依目前歌詞狀態挑出要顯示的歌詞動作與順序。
/// [canAiGenerate] 為「完全沒有歌詞」(可從音訊直接產生);
/// [canAutoAlign] 為「已有歌詞」(已同步者為重新同步);[hasLyrics] 為「已有歌詞」。
/// [includeDisplay] 為 false 時不列顯示設定(字體大小 / 對齊方式)。
List<LyricsMenuAction> lyricsMenuActions({
  required bool canAiGenerate,
  required bool canAutoAlign,
  required bool hasLyrics,
  bool includeDisplay = true,
}) {
  return [
    // 無歌詞時提供四種取得方式:上網搜尋、編輯、從檔案匯入、自動產生。
    if (!hasLyrics) LyricsMenuAction.searchOnline,
    if (!hasLyrics) LyricsMenuAction.edit,
    if (!hasLyrics) LyricsMenuAction.import,
    if (canAiGenerate) LyricsMenuAction.aiGenerate,
    if (canAutoAlign) ...[
      LyricsMenuAction.autoAlignWhisperX,
      LyricsMenuAction.autoAlignAeneas,
    ],
    if (hasLyrics) ...[
      if (includeDisplay) ...[
        LyricsMenuAction.fontSize,
        LyricsMenuAction.textAlign,
      ],
      LyricsMenuAction.edit,
      LyricsMenuAction.reimport,
      LyricsMenuAction.download,
      LyricsMenuAction.delete,
    ],
  ];
}

/// 執行歌詞選單動作。
Future<void> runLyricsMenuAction(
  BuildContext context,
  WidgetRef ref,
  LyricsMenuAction action, {
  required String pathKey,
  required String title,
}) async {
  // 記錄使用者點了哪個歌詞功能(只送動作名,不送歌名 / 路徑)。
  logAnalyticsAction(action);

  // 需要網路的動作先檢查連線;離線時直接提示,不進入登入 / 用量等後續流程。
  if (action.needsNetwork) {
    if (!await ensureOnline(ref)) return;
    if (!context.mounted) return;
  }

  // 已同步的歌詞重新對時會覆蓋現有時間軸並消耗用量,先確認。
  if ((action == LyricsMenuAction.autoAlignAeneas ||
          action == LyricsMenuAction.autoAlignWhisperX) &&
      (ref.read(trackLyricsProvider(pathKey)).valueOrNull?.synced ?? false)) {
    if (!await _confirmResync(context)) return;
    if (!context.mounted) return;
  }

  // 自動產生 / 自動對時走雲端服務,需登入;未登入時先詢問並導向登入頁。
  if (action == LyricsMenuAction.aiGenerate ||
      action == LyricsMenuAction.autoAlignAeneas ||
      action == LyricsMenuAction.autoAlignWhisperX) {
    final l10n = AppLocalizations.of(context)!;
    final message = action == LyricsMenuAction.aiGenerate
        ? l10n.lyrics_ai_generate_need_login
        : l10n.lyrics_auto_align_need_login;
    final signedIn = await ensureSignedInForLyrics(
      context,
      ref,
      message: message,
    );
    if (!signedIn || !context.mounted) return;

    // 登入後才檢查用量,避免未登入時誤讀 usage/{uid}。
    final withinLimit = await ensureWithinUsageLimitForLyrics(
      context,
      ref,
      pathKey: pathKey,
    );
    if (!withinLimit || !context.mounted) return;
  }

  switch (action) {
    case LyricsMenuAction.autoAlignAeneas:
      await runLyricsAutoAlign(
        context,
        ref,
        pathKey: pathKey,
        title: title,
        engine: LyricsAlignEngine.aeneas,
      );
    case LyricsMenuAction.autoAlignWhisperX:
      await runLyricsAutoAlign(
        context,
        ref,
        pathKey: pathKey,
        title: title,
        engine: LyricsAlignEngine.whisperx,
      );
    case LyricsMenuAction.fontSize:
      showLyricsFontSizeSheet(context);
    case LyricsMenuAction.textAlign:
      showLyricsTextAlignSheet(context);
    case LyricsMenuAction.searchOnline:
      await runLyricsOnlineSearch(context, ref, pathKey: pathKey, title: title);
    case LyricsMenuAction.edit:
      await runLyricsEdit(context, pathKey: pathKey, title: title);
    case LyricsMenuAction.import:
    case LyricsMenuAction.reimport:
      await runLyricsImport(context, ref, pathKey: pathKey, title: title);
    case LyricsMenuAction.download:
      await runLyricsDownload(context, ref, pathKey: pathKey, title: title);
    case LyricsMenuAction.delete:
      await _confirmDelete(context, ref, pathKey);
    case LyricsMenuAction.aiGenerate:
      await runLyricsAiGenerate(context, ref, pathKey: pathKey, title: title);
  }
}

Future<bool> _confirmResync(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.lyrics_auto_resync_confirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.common_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.common_confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String pathKey,
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
  logAnalyticsAction(
    LyricsAction.deleteConfirm,
    result: ok == true ? AnalyticsResult.confirmed : AnalyticsResult.cancelled,
  );
  if (ok != true || !context.mounted) return;
  await ref.read(lyricsRepositoryProvider).deleteByPathKey(pathKey);
  ref.invalidate(trackLyricsProvider(pathKey));
}
