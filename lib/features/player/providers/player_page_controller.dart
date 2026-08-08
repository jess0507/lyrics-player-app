import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/features/player/player_page.dart';

/// 全螢幕播放頁的開關狀態與展開邏輯(viewmodel)。
///
/// state 代表播放頁是否已開啟,避免快速連點時重複堆疊 PlayerPage。
class PlayerPageController extends Notifier<bool> {
  @override
  bool build() => false;

  /// 由下往上滑入全螢幕播放頁;若已開啟則忽略。
  ///
  /// 用一般 page route 而非滿版 bottom sheet:route 不會像
  /// `useSafeArea: false` 的 sheet 把頂部 inset 清掉(免去補 padding 的
  /// hack),且為不透明頁面,開啟期間下層的分頁 / mini player 不需繪製。
  Future<void> open(BuildContext context) async {
    if (state) return;
    state = true;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PlayerPage(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  SlideTransition(
                    position: animation.drive(
                      Tween(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child: child,
                  ),
        ),
      );
    } finally {
      state = false;
    }
  }
}

final playerPageControllerProvider =
    NotifierProvider<PlayerPageController, bool>(PlayerPageController.new);
