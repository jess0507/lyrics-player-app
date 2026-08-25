import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/router/app_router.dart';
import 'package:seek_player/router/safe_back_button_dispatcher.dart';

/// 提供給 `MaterialApp.router` 的返回鍵 dispatcher。
///
/// GoRouter 建構時固定用 `RootBackButtonDispatcher()`,無法從外部替換,
/// 因此 App 改成分別傳入 delegate / parser / provider,並在此掛上
/// [SafeRootBackButtonDispatcher]。
final backButtonDispatcherProvider = Provider<BackButtonDispatcher>((ref) {
  return SafeRootBackButtonDispatcher(ref.watch(routerProvider));
});
