import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/lyrics/services/lyrics_import_service.dart';
import 'package:seek_player/features/player/widgets/lyrics_view.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 開啟 [LyricsPastePage] 讓使用者貼上 / 輸入歌詞;儲存成功後提示並返回。
/// 成功時匯入服務會 invalidate 對應的 trackLyricsProvider,視圖自動重讀。
Future<void> runLyricsPaste(
  BuildContext context, {
  required String pathKey,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LyricsPastePage(pathKey: pathKey, title: title),
    ),
  );
  if (saved == true) showAppToast(l10n.lyrics_import_success);
}

/// 貼上歌詞頁:多行文字框 + 儲存。格式(LRC / SRT / VTT / 純文字)由
/// [LyricsImportService.importFromText] 依內文判定;失敗時留在頁面提示原因。
class LyricsPastePage extends ConsumerStatefulWidget {
  const LyricsPastePage({
    super.key,
    required this.pathKey,
    required this.title,
  });

  final String pathKey;
  final String title;

  @override
  ConsumerState<LyricsPastePage> createState() => _LyricsPastePageState();
}

class _LyricsPastePageState extends ConsumerState<LyricsPastePage> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await ref
          .read(lyricsImportServiceProvider)
          .importFromText(
            pathKey: widget.pathKey,
            title: widget.title,
            content: _controller.text,
          );
      logAnalyticsAction(
        LyricsAction.pasteSave,
        result: AnalyticsResult.success,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on LyricsImportException catch (e, s) {
      logAnalyticsAction(LyricsAction.pasteSave, result: e.error);
      reportError(e, s, reason: '貼上歌詞失敗（${e.error.name}）');
      showAppToast(lyricsImportErrorText(l10n, e.error));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lyrics_paste),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => TextButton(
              onPressed: _saving || value.text.trim().isEmpty ? null : _save,
              child: Text(l10n.common_save),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            expands: true,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: l10n.lyrics_paste_hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ),
    );
  }
}
