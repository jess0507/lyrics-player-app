import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seek_player/router/app_router.dart';
import 'package:seek_player/shared/widgets/app_toast.dart';

void main() {
  testWidgets('app toast 寬度隨內容縮,不貼滿螢幕', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    showAppToast('登入成功');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final materialFinder = find.byWidgetPredicate(
      (w) => w is Material && w.color == Colors.white,
    );
    expect(materialFinder, findsOneWidget);

    final toastSize = tester.getSize(materialFinder);
    final screenSize = tester.getSize(find.byType(MaterialApp));
    debugPrint('toast width: ${toastSize.width}, '
        'screen width: ${screenSize.width}');

    expect(toastSize.width, lessThan(screenSize.width - 100));
  });
}
