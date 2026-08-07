import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import 'package:seek_player/core/audio/audio_player_service.dart';
import 'package:seek_player/features/lyrics/models/lyrics.dart';

/// 同步歌詞:目前行 highlight + 自動置中捲動 + 點行 seek。
/// 位置來源 `positionStream`(節流 ~200ms),目前行以二分搜尋定位;
/// 使用者手動捲動時暫停自動置中數秒後恢復。
class LyricsSyncedView extends ConsumerStatefulWidget {
  const LyricsSyncedView({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  ConsumerState<LyricsSyncedView> createState() => _LyricsSyncedViewState();
}

class _LyricsSyncedViewState extends ConsumerState<LyricsSyncedView> {
  /// 手動捲動後恢復自動置中的延遲。
  static const _resumeDelay = Duration(seconds: 4);

  final _scrollController = ScrollController();
  final _lineKeys = <GlobalKey>[];
  StreamSubscription<Duration>? _posSub;
  Timer? _resumeTimer;
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

  void _scrollToCurrent() {
    if (_currentIndex < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[_currentIndex].currentContext;
      if (ctx == null) return; // 目前行未在快取範圍內,跳過(下次更新再追)
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is UserScrollNotification && n.direction != ScrollDirection.idle) {
      _autoScrollPaused = true;
      _resumeTimer?.cancel();
      _resumeTimer = Timer(_resumeDelay, () {
        _autoScrollPaused = false;
        _scrollToCurrent();
      });
    }
    return false;
  }

  void _seekTo(Duration time) {
    ref.read(audioPlayerServiceProvider).seek(time);
    // 點行後立即跟隨,不等手動捲動的恢復計時。
    _resumeTimer?.cancel();
    _autoScrollPaused = false;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = widget.lyrics.lines;
    // 非當前行的顏色:light theme 用 onSurface(近黑)壓 0.8,讓歌詞在淺底
    // 上夠深、清楚;dark theme 維持 onSurfaceVariant 的柔和度避免過亮刺眼。
    final inactiveColor = theme.brightness == Brightness.light
        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
        : theme.colorScheme.onSurfaceVariant;
    // 當前行文字色:light mode 用深色(onSurface),避免封面色偏淺時看不清;
    // dark mode 維持 primary 作為高亮色。
    final activeColor = theme.brightness == Brightness.light
        ? theme.colorScheme.onSurface
        : theme.colorScheme.primary;
    return NotificationListener<ScrollNotification>(
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
                textAlign: TextAlign.center,
                style:
                    (active
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                          color: active ? activeColor : inactiveColor,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
              ),
            ),
          );
        },
      ),
    );
  }
}
