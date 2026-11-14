import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/features/lyrics/services/lyrics_import_service.dart';
import 'package:seek_player/features/lyrics/services/lyrics_export_service.dart';
import 'package:seek_player/features/player/widgets/lyrics_edit_more_button.dart';
import 'package:seek_player/features/lyrics/services/lyrics_repository.dart';
import 'package:seek_player/features/player/providers/lyrics_edit_font_size_controller.dart';
import 'package:seek_player/features/player/widgets/lyrics_edit_bottom_bar.dart';
import 'package:seek_player/features/player/widgets/lyrics_edit_font_size_panel.dart';
import 'package:seek_player/features/player/widgets/lyrics_view.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

/// 開啟 [LyricsEditPage] 讓使用者編輯(輸入或貼上)歌詞;儲存成功後頁面自行提示並返回。
/// 成功時匯入服務會 invalidate 對應的 trackLyricsProvider,視圖自動重讀。
Future<void> runLyricsEdit(
  BuildContext context, {
  required String trackId,
  required String title,
}) async {
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LyricsEditPage(trackId: trackId, title: title),
    ),
  );
}

/// 預覽 / 編輯歌詞頁:預先帶入本曲現有歌詞原文,從播放頁([runLyricsEdit])
/// 與工具「編輯歌詞」進入。已有歌詞時先以唯讀預覽,點文字後才進入編輯
/// (原地切換,保留捲動與點擊位置);沒有歌詞時直接編輯。
/// AppBar 標題為歌詞名稱(曲名)。預覽時右上為「字體大小」(浮動字級面板)與
/// 「更多」(分享、匯出歌詞檔),底部不放按鈕;編輯中右上為復原、重做、儲存
/// (儲存後回到預覽),底部列為字體大小、分享,皆為純圖示。
/// 格式(LRC / SRT / VTT / 純文字)由 [LyricsImportService.importFromText]
/// 依內文判定;失敗時留在頁面提示原因。
class LyricsEditPage extends ConsumerStatefulWidget {
  const LyricsEditPage({
    super.key,
    required this.trackId,
    required this.title,
    this.initialContent,
  });

  /// 歌詞所屬曲目;null 為獨立歌詞檔(工具「編輯歌詞」直接開檔),
  /// 此時儲存改為另存成歌詞檔。
  final String? trackId;

  /// 標題(歌詞名稱):曲名,或獨立歌詞檔的檔名(如 `A-1.lrc`)。
  final String title;

  /// 初始內容;null 時讀 [trackId] 現有的歌詞。
  final String? initialContent;

  @override
  ConsumerState<LyricsEditPage> createState() => _LyricsEditPageState();
}

class _LyricsEditPageState extends ConsumerState<LyricsEditPage> {
  late final TextEditingController _controller;
  final _undoController = UndoHistoryController();
  bool _saving = false;
  bool _showFontSize = false;

  /// false 為預覽(唯讀);點文字後進入編輯。
  late bool _editing;

  @override
  void initState() {
    super.initState();
    final trackId = widget.trackId;
    final content =
        widget.initialContent ??
        (trackId == null
            ? null
            : ref
                  .read(lyricsRepositoryProvider)
                  .findByTrackId(trackId)
                  ?.content);
    _controller = TextEditingController(text: content ?? '');
    _editing = _controller.text.trim().isEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    _undoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final trackId = widget.trackId;
    if (trackId == null) {
      // 獨立歌詞檔:另存成檔案(系統存檔對話框),取消時留在編輯。
      await _export();
      if (mounted) setState(() => _saving = false);
      return;
    }
    try {
      await ref
          .read(lyricsImportServiceProvider)
          .importFromText(
            trackId: trackId,
            title: widget.title,
            content: _controller.text,
          );
      logAnalyticsAction(
        LyricsAction.editSave,
        result: AnalyticsResult.success,
      );
      showAppToast(l10n.lyrics_import_success);
      if (!mounted) return;
      // 存完留在本頁,回到預覽。
      FocusScope.of(context).unfocus();
      setState(() {
        _saving = false;
        _editing = false;
        _showFontSize = false;
      });
    } on LyricsImportException catch (e, s) {
      logAnalyticsAction(LyricsAction.editSave, result: e.error);
      reportError(e, s, reason: '編輯歌詞失敗（${e.error.name}）');
      showAppToast(lyricsImportErrorText(l10n, e.error));
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 預覽中點文字:切成可編輯。點擊已讓文字框取得焦點,唯讀解除時
  /// EditableText 會建立輸入連線並叫出鍵盤,游標停在點擊位置。
  void _startEditing() {
    if (!_editing) setState(() => _editing = true);
  }

  /// 以系統分享面板分享文字框內容;帶上按鈕位置作為 iPad 的錨點。
  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final result = await SharePlus.instance.share(
      ShareParams(
        text: _controller.text,
        subject: widget.title,
        sharePositionOrigin: origin,
      ),
    );
    logAnalyticsAction(LyricsAction.editShare, result: result.status);
  }

  /// 把目前內容匯出成歌詞檔,檔名為歌詞名稱;取消存檔不提示。
  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final saved = await ref
          .read(lyricsExportServiceProvider)
          .exportText(name: widget.title, content: _controller.text);
      logAnalyticsAction(
        LyricsAction.editExport,
        result: saved ? AnalyticsResult.success : AnalyticsResult.cancelled,
      );
      if (saved) showAppToast(l10n.lyrics_download_success);
      // 獨立歌詞檔另存成功後回到預覽。
      if (saved && widget.trackId == null && mounted) {
        FocusScope.of(context).unfocus();
        setState(() {
          _editing = false;
          _showFontSize = false;
        });
      }
    } catch (e, s) {
      logAnalyticsAction(
        LyricsAction.editExport,
        result: AnalyticsResult.failure,
      );
      reportError(e, s, reason: '編輯歌詞匯出失敗');
      showAppToast(l10n.lyrics_download_failed);
    }
  }

  void _onMore(BuildContext buttonContext, LyricsEditMoreAction action) {
    switch (action) {
      case LyricsEditMoreAction.share:
        _share(buttonContext);
      case LyricsEditMoreAction.export:
        _export();
    }
  }

  /// 開關浮動字級面板;預覽(右上字體圖示)與編輯(底部列)共用。
  void _toggleFontSize() => setState(() => _showFontSize = !_showFontSize);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = ref.watch(lyricsEditFontSizeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_editing) ...[
            IconButton(
              tooltip: l10n.lyrics_font_size,
              icon: const Icon(Icons.text_fields),
              color: _showFontSize
                  ? Theme.of(context).colorScheme.primary
                  : null,
              onPressed: _toggleFontSize,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => LyricsEditMoreButton(
                enabled: value.text.trim().isNotEmpty,
                onSelected: _onMore,
              ),
            ),
          ],
          if (_editing) ...[
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _undoController,
              builder: (context, undo, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.common_undo,
                    icon: const Icon(Icons.undo),
                    onPressed: undo.canUndo ? _undoController.undo : null,
                  ),
                  IconButton(
                    tooltip: l10n.common_redo,
                    icon: const Icon(Icons.redo),
                    onPressed: undo.canRedo ? _undoController.redo : null,
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => IconButton(
                tooltip: l10n.common_save,
                icon: const Icon(Icons.check),
                onPressed: _saving || value.text.trim().isEmpty ? null : _save,
              ),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              undoController: _undoController,
              readOnly: !_editing,
              autofocus: _editing,
              onTap: _startEditing,
              expands: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: fontSize, height: 1.6),
              decoration: InputDecoration(
                hintText: l10n.lyrics_edit_hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_showFontSize)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: LyricsEditFontSizePanel(),
            ),
        ],
      ),
      // 預覽時底部不放按鈕。
      bottomNavigationBar: !_editing
          ? null
          : ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => LyricsEditBottomBar(
                onShare: value.text.trim().isEmpty ? null : _share,
                fontSizeActive: _showFontSize,
                onFontSize: _toggleFontSize,
              ),
            ),
    );
  }
}
