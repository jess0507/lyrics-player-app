import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// 回報已捕捉的非致命錯誤到 Crashlytics。
///
/// Firebase 未初始化(未設定 / 啟動時初始化失敗)時安靜略過;
/// debug build 由 main.dart 關閉收集,上報為 no-op——但仍會 [debugPrint],
/// 讓本機開發時在 console 直接看到錯誤與 stack trace。
void reportError(Object error, StackTrace stack, {String? reason}) {
  debugPrint('[reportError] ${reason ?? error.runtimeType}\n$error\n$stack');
  if (Firebase.apps.isEmpty) return;
  unawaited(
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: false,
    ),
  );
}

/// 將登入使用者的 uid 綁定到 Crashlytics,之後的回報都會帶上該識別。
///
/// 登出時清空。僅記 uid 不記 email,避免把 PII 傳進 Crashlytics。
/// 須在 Firebase 初始化成功後呼叫。
void bindCrashUserIdentifier() {
  FirebaseAuth.instance.authStateChanges().listen((user) {
    unawaited(
      FirebaseCrashlytics.instance.setUserIdentifier(user?.uid ?? ''),
    );
  });
}
