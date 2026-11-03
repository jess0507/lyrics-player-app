import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 登入流程(含登入後的同步判斷)是否進行中。進行中時帳戶頁即使已登入
/// 也繼續顯示登入畫面與其 loading,等同步判斷完成才切到已登入畫面。
final signInInProgressProvider = StateProvider<bool>((ref) => false);
