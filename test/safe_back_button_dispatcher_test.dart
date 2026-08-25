import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:seek_player/router/safe_back_button_dispatcher.dart';

void main() {
  testWidgets('路由尚未解析完成時按返回鍵不會丟 Bad state: No element', (tester) async {
    // 尚未掛上 Router 的 GoRouter,delegate 的 matchList 是空的,
    // 等同 App 啟動途中的狀態。
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    expect(router.routerDelegate.currentConfiguration.isEmpty, isTrue);

    final dispatcher = SafeRootBackButtonDispatcher(router);
    await expectLater(dispatcher.didPopRoute(), completion(isFalse));
  });
}
