import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:seek_player/core/analytics/analytics_events.dart';

/// Google Analytics(Firebase Analytics)事件上報的薄封裝。
///
/// 與 crash_reporter.dart 相同:Firebase 未初始化時安靜略過,呼叫端不需
/// 判斷;上報失敗不影響功能,一律 fire-and-forget。
/// 事件、參數與登入方式集中定義在 analytics_events.dart,呼叫端只傳 enum。
/// 事件名與參數只放功能層級資訊(動作名、路由樣板),不放 trackId、
/// 歌名、email 等可能含 PII 的內容。
FirebaseAnalytics? get _analytics =>
    Firebase.apps.isEmpty ? null : FirebaseAnalytics.instance;

/// 記錄自訂事件 [event];[parameters] 的值可直接傳 enum(見 [toGaParameters])。
void logAnalyticsEvent(
  AnalyticsEvent event, [
  Map<AnalyticsParam, Object>? parameters,
]) {
  final analytics = _analytics;
  if (analytics == null) return;
  final name = event.gaName;
  unawaited(
    analytics
        .logEvent(
          name: name,
          parameters: parameters == null ? null : toGaParameters(parameters),
        )
        .catchError((Object e) => debugPrint('[analytics] $name 失敗:$e')),
  );
}

/// 記錄功能動作:事件由 [action] 的 [AnalyticsAction.analyticsEvent] 決定,
/// 參數見 [actionParameters]。各功能的使用者操作一律走這個。
///
/// [option] 可傳 enum / 數字 / bool / 低基數字串(如語系 tag),勿傳 PII。
void logAnalyticsAction(
  AnalyticsAction action, {
  AnalyticsSource? source,
  Object? option,
  Object? result,
}) {
  final analytics = _analytics;
  if (analytics == null) return;
  final name = action.analyticsEvent.gaName;
  unawaited(
    analytics
        .logEvent(
          name: name,
          parameters: actionParameters(
            action,
            source: source,
            option: option,
            result: result,
          ),
        )
        .catchError((Object e) => debugPrint('[analytics] $name 失敗:$e')),
  );
}

/// 登入成功:新帳號記 `sign_up`,既有帳號記 `login`(GA 建議事件)。
void logAnalyticsSignIn(
  UserCredential credential,
  AnalyticsSignInMethod method,
) {
  final analytics = _analytics;
  if (analytics == null) return;
  final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
  unawaited(
    (isNewUser
            ? analytics.logSignUp(signUpMethod: method.gaName)
            : analytics.logLogin(loginMethod: method.gaName))
        .catchError((Object e) => debugPrint('[analytics] sign-in 失敗:$e')),
  );
}

/// 將登入使用者的 uid 綁到 Analytics 的 user id,登出時清空。
/// 僅記 uid 不記 email。須在 Firebase 初始化成功後呼叫。
void bindAnalyticsUserId() {
  FirebaseAuth.instance.authStateChanges().listen((user) {
    unawaited(FirebaseAnalytics.instance.setUserId(id: user?.uid));
  });
}

/// 監聽 [router] 的路由變化並記 `screen_view`。
///
/// 用路由樣板(如 `/tools/:tool`)當 screen name,不用實際 location,
/// 避免把 query / path 參數(可能含檔案路徑)送出去;
/// 也涵蓋 StatefulShellRoute 切換分頁(不經 Navigator push,NavigatorObserver 抓不到)。
/// 回傳移除監聽的 callback,供 provider dispose 時呼叫。
VoidCallback bindAnalyticsScreenTracking(GoRouter router) {
  String? lastScreen;
  void listener() {
    final analytics = _analytics;
    if (analytics == null) return;
    final screen = router.routerDelegate.currentConfiguration.fullPath;
    if (screen.isEmpty || screen == lastScreen) return;
    lastScreen = screen;
    unawaited(
      analytics
          .logScreenView(screenName: screen, screenClass: screen)
          .catchError((Object e) => debugPrint('[analytics] screen 失敗:$e')),
    );
  }

  router.routerDelegate.addListener(listener);
  return () => router.routerDelegate.removeListener(listener);
}
