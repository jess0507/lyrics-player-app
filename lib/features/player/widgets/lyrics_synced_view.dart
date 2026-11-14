import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/lyrics/models/lyrics.dart';
import 'package:seek_player/features/player/widgets/lyrics_sync_button.dart';

/// 同步歌詞:目前行 highlight + 自動置中捲動 + 點行 seek。
/// 位置來源 `positionStream`(節流 ~200ms),目前行以二分搜尋定位;
/// 使用者手動捲動後暫停自動置中,並顯示「同步」按鈕;點按鈕(或點某行 seek)
/// 才捲回目前播放行並恢復自動置中。
class LyricsSyncedView extends ConsumerStatefulWidget {
  const LyricsSyncedView({
    super.key,
    required this.lyrics,
    this.textAlign = TextAlign.left,
  });

  final Lyrics lyrics;

  /// 歌詞的水平對齊方式,由 [LyricsView] 依使用者設定傳入。
  final TextAlign textAlign;

  @override
  ConsumerState<LyricsSyncedView> createState() => _LyricsSyncedViewState();
}

class _LyricsSyncedViewState extends ConsumerState<LyricsSyncedView> {
  final _scrollController = ScrollController();
  final _lineKeys = <GlobalKey>[];
  StreamSubscription<Duration>? _posSub;
  int _currentIndex = -1;
  bool _autoScrollPaused = false;

  @override
  void initState() {
    super.initState();
    _buildKeys();
    final audio = ref.read(audioPlayerServiceProvider);
    _posSub = audio.player.positionStream
        .throttleTime(
          const Duration(milliseconds: 200),
          leading: true,
          trailing: true,
        )
        .listen(_onPosition);
  }

  @override
  void didUpdateWidget(covariant LyricsSyncedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 換曲後歌詞行數 / 內容改變,重建對齊用的 keys 並重置目前行。
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      _buildKeys();
      _currentIndex = -1;
      // 新歌詞從頭開始跟隨,不沿用上一首的手動捲動狀態。
      _autoScrollPaused = false;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  void _buildKeys() {
    _lineKeys
      ..clear()
      ..addAll(List.generate(widget.lyrics.lines.length, (_) => GlobalKey()));
  }

  void _onPosition(Duration pos) {
    final index = _lineIndexFor(pos);
    if (index == _currentIndex || !mounted) return;
    setState(() => _currentIndex = index);
    if (!_autoScrollPaused) _scrollToCurrent();
  }

  /// 二分搜尋:最後一個 time ≤ pos 的行;都比 pos 大則回 -1(尚未進首行)。
  int _lineIndexFor(Duration pos) {
    final lines = widget.lyrics.lines;
    var lo = 0;
    var hi = lines.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time! <= pos) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /// 將目前行捲到中央。目前行若尚未被 ListView build(例如拖曳時間軸跳很遠),
  /// 先依已 build 的行估算位置跳過去,最多重試 [attempts] 次;仍定位不到就
  /// 改為暫停自動置中並顯示「同步」按鈕,讓使用者知道歌詞與播放進度不一致。
  void _scrollToCurrent({int attempts = 3}) {
    final index = _currentIndex;
    if (index < 0 || index >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 這一幀之間可能換曲(keys 重建、_currentIndex 重設為 -1)或位置跳到
      // 首行之前,因此以排程當下的 index 重新驗證,避免越界。
      if (!mounted || index != _currentIndex || index >= _lineKeys.length) {
        return;
      }
      final ctx = _lineKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        return;
      }
      if (attempts > 0 && _jumpNear(index)) {
        _scrollToCurrent(attempts: attempts - 1);
      } else if (!_autoScrollPaused) {
        setState(() => _autoScrollPaused = true);
      }
    });
  }

  /// 目前行未 build 時,依已 build 行的位置與平均行高估算 [index] 的位置,
  /// 直接跳到讓它接近畫面中央處。回傳是否有跳動。
  bool _jumpNear(int index) {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return false;
    final centerDy = viewport
        .localToGlobal(Offset(0, viewport.size.height / 2))
        .dy;

    int? first;
    int? last;
    for (var i = 0; i < _lineKeys.length; i++) {
      if (_lineKeys[i].currentContext != null) {
        first ??= i;
        last = i;
      }
    }

    double target;
    if (first == null || last == null) {
      // 完全沒有已 build 的行:退回依行數比例估算。
      final lineCount = _lineKeys.length;
      final ratio = lineCount <= 1 ? 0.0 : index / (lineCount - 1);
      target = position.maxScrollExtent * ratio;
    } else {
      final firstBox =
          _lineKeys[first].currentContext!.findRenderObject() as RenderBox;
      final lastBox =
          _lineKeys[last].currentContext!.findRenderObject() as RenderBox;
      final firstDy = firstBox.localToGlobal(Offset.zero).dy;
      final lastDy = lastBox.localToGlobal(Offset.zero).dy;
      final avgExtent = last > first
          ? (lastDy - firstDy) / (last - first)
          : firstBox.size.height;
      final estimatedDy = firstDy + (index - first) * avgExtent;
      target = position.pixels + estimatedDy - centerDy;
    }
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 1) return false;
    _scrollController.jumpTo(clamped);
    return true;
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is UserScrollNotification &&
        n.direction != ScrollDirection.idle &&
        !_autoScrollPaused) {
      setState(() => _autoScrollPaused = true);
    }
    return false;
  }

  /// 「同步」按鈕:捲回目前播放行並恢復自動置中。
  void _syncToCurrent() {
    logAnalyticsAction(LyricsAction.scrollToCurrent);
    setState(() => _autoScrollPaused = false);
    final index = _currentIndex;
    if (index < 0) {
      // 尚未進入首行:回到最上方。
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    _scrollToCurrent();
  }

  void _seekTo(Duration time) {
    logAnalyticsAction(LyricsAction.lineSeek);
    ref.read(audioPlayerServiceProvider).seek(time);
    // 點行後立即恢復跟隨,並收起「同步」按鈕。
    if (_autoScrollPaused) setState(() => _autoScrollPaused = false);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = widget.lyrics.lines;
    // 歌詞顏色固定不隨封面色或 colorScheme 變動:light mode 當前行純黑、
    // 其他行 #666666;dark mode 當前行純白、其他行 #CCCCCC。
    final isLight = theme.brightness == Brightness.light;
    final activeColor = isLight ? Colors.black : Colors.white;
    final inactiveColor = isLight
        ? const Color(0xFF666666)
        : const Color(0xFFCCCCCC);
    final list = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 8),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final line = lines[i];
          final active = i == _currentIndex;
          return InkWell(
            key: _lineKeys[i],
            onTap: line.time == null ? null : () => _seekTo(line.time!),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                line.text.isEmpty ? ' ' : line.text,
                textAlign: widget.textAlign,
                style:
                    (active
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                          fontSize: active ? 20 : 18,
                          color: active ? activeColor : inactiveColor,
                          fontWeight: FontWeight.w600,
                        ),
              ),
            ),
          );
        },
      ),
    );
    return Stack(
      children: [
        list,
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: LyricsSyncButton(
              visible: _autoScrollPaused,
              onPressed: _syncToCurrent,
            ),
          ),
        ),
      ],
    );
  }
}
