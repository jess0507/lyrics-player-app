import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 會擋掉「路由尚未解析完成就按下系統返回鍵」的 root back dispatcher。
///
/// go_router 的 `GoRouterDelegate.popRoute()` 內部直接取
/// `currentConfiguration.matches.last`,在 matchList 還是空的時候
/// (App 剛啟動、第一次 `setNewRoutePath` 之前) 按 Android 返回鍵
/// 會丟 `Bad state: No element`。這裡在委派給 delegate 之前先擋一層,
/// 空 matchList 時退回由 root navigator 自行處理(通常代表沒東西可 pop,
/// 交還給系統結束 Activity)。
class SafeRootBackButtonDispatcher extends RootBackButtonDispatcher {
  SafeRootBackButtonDispatcher(this._router);

  final GoRouter _router;

  @override
  Future<bool> didPopRoute() {
    if (_router.routerDelegate.currentConfiguration.isEmpty) {
      final navigator = _router.routerDelegate.navigatorKey.currentState;
      return navigator?.maybePop() ?? Future<bool>.value(false);
    }
    return super.didPopRoute();
  }
}
