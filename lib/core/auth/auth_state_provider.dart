import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/auth/auth_service.dart';

/// 監聽登入狀態；Firebase 不可用時不應被讀取（UI 會先檢查
/// [firebaseAvailableProvider]）。
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});
