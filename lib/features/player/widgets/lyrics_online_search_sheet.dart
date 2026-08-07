import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crash_reporter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../lyrics/online/models/lrclib_result.dart';
import '../../lyrics/online/providers/lyrics_online_search_service_provider.dart';
import '../../lyrics/online/services/lrclib_client.dart';
import '../../lyrics/online/services/lyrics_online_search_service.dart';

/// 線上搜尋歌詞的完整面板:上方為預填查詢字串的搜尋欄(可編輯後重查),
/// 下方依狀態顯示「搜尋中 / 查無結果 / 候選結果列表」。開啟後立即以
/// [query] 的結構化參數(title/artist/album/duration)做第一次查詢;
/// 使用者改字重查時改走關鍵字比對([LyricsOnlineSearchService.searchByKeyword])。
///
/// 同名曲(尤其翻唱、live 版)可能有多筆候選,不自動選第一筆,交由使用者
/// 確認以免套錯歌詞。後續套用以呼叫端的 [context]/[ref] 執行,避免本表單
/// 關閉後沿用已失效的 context(比照 [showLyricsActionsSheet] 的既有模式)。
Future<void> showLyricsOnlineSearchSheet(
  BuildContext context,
  WidgetRef ref, {
  required String trackId,
  required String title,
  required LyricsOnlineSearchQuery query,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _LyricsOnlineSearchSheet(
      parentContext: context,
      parentRef: ref,
      trackId: trackId,
      title: title,
      query: query,
    ),
  );
}

class _LyricsOnlineSearchSheet extends ConsumerStatefulWidget {
  const _LyricsOnlineSearchSheet({
    required this.parentContext,
    required this.parentRef,
    required this.trackId,
    required this.title,
    required this.query,
  });

  final BuildContext parentContext;
  final WidgetRef parentRef;
  final String trackId;
  final String title;
  final LyricsOnlineSearchQuery query;

  @override
  ConsumerState<_LyricsOnlineSearchSheet> createState() =>
      _LyricsOnlineSearchSheetState();
}

class _LyricsOnlineSearchSheetState
    extends ConsumerState<_LyricsOnlineSearchSheet> {
  late final TextEditingController _keywordController;

  /// 上一次查詢用的字串;查詢字串沒變就不重查(失敗後重試除外)。
  /// 初值為預填字串,因為開面板時已用它(的結構化參數版本)查過一次。
  late String _lastKeyword;
  var _searching = true;
  var _failed = false;
  List<LrclibResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _lastKeyword = _initialKeyword;
    _keywordController = TextEditingController(text: _lastKeyword);
    _search(
      () => ref.read(lyricsOnlineSearchServiceProvider).search(widget.query),
    );
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  /// 搜尋欄預填的查詢字串:曲名 + 演出者(重查時作為關鍵字使用)。
  String get _initialKeyword {
    final artist = widget.query.artist;
    return [
      widget.query.title,
      if (artist != null && artist.isNotEmpty) artist,
    ].join(' ');
  }

  Future<void> _searchByKeyword() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty || _searching) return;
    if (keyword == _lastKeyword && !_failed) return;
    _lastKeyword = keyword;
    // 收起鍵盤,讓下方的搜尋狀態 / 結果列表有完整空間可看。
    FocusScope.of(context).unfocus();
    await _search(
      () =>
          ref.read(lyricsOnlineSearchServiceProvider).searchByKeyword(keyword),
    );
  }

  Future<void> _search(Future<List<LrclibResult>> Function() run) async {
    setState(() {
      _searching = true;
      _failed = false;
    });
    List<LrclibResult> results;
    try {
      results = await run();
    } on LrclibException catch (e, s) {
      reportError(e, s, reason: '線上搜尋歌詞失敗');
      if (!mounted) return;
      setState(() {
        _searching = false;
        _failed = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      // 搜尋欄取得焦點時把面板整體抬到鍵盤上方。
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.lyrics_search_online,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _keywordController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchByKeyword(),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchByKeyword,
                    ),
                  ),
                ),
              ),
              Flexible(child: _buildBody(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_searching) {
      return _CenteredHint(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.lyrics_search_online_searching),
          ],
        ),
      );
    }
    if (_failed) {
      return _CenteredHint(child: Text(l10n.lyrics_search_online_failed));
    }
    if (_results.isEmpty) {
      return _CenteredHint(child: Text(l10n.lyrics_search_online_no_result));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.lyrics_search_online_select,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final result = _results[index];
              return ListTile(
                leading: Icon(
                  result.hasSyncedLyrics ? Icons.sync : Icons.subject,
                ),
                title: Text(result.trackName),
                subtitle: Text(_subtitle(result)),
                onTap: () {
                  Navigator.of(context).pop();
                  _apply(result);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _subtitle(LrclibResult result) {
    final parts = [
      result.artistName,
      if (result.albumName case final album? when album.isNotEmpty) album,
      if (result.durationSeconds case final seconds?) _formatDuration(seconds),
    ];
    return parts.join(' · ');
  }

  String _formatDuration(double seconds) {
    final total = seconds.round();
    final minutes = total ~/ 60;
    final secs = total % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _apply(LrclibResult result) async {
    final l10n = AppLocalizations.of(widget.parentContext)!;
    await widget.parentRef
        .read(lyricsOnlineSearchServiceProvider)
        .apply(trackId: widget.trackId, title: widget.title, result: result);
    showAppToast(l10n.lyrics_search_online_applied);
  }
}

/// 「搜尋中 / 查無結果 / 失敗」的置中提示,固定最小高度避免面板高度跳動。
class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}
