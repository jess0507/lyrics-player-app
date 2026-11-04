// 由 google-services.json / apps:sdkconfig 手動轉換而來(Android)。
// iOS 設定已移除(尚未上架);上架 iOS 時從 git 歷史或 Firebase Console 取回。
// 若日後新增其他平台，請改用 `flutterfire configure` 重新產生此檔。
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web 尚未設定 Firebase，請執行 flutterfire configure。');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // debug build 的 applicationId 為 com.js.seek_player.dev(見
        // android/app/build.gradle.kts),需對應 Firebase 上的 dev app。
        return kDebugMode ? androidDev : android;
      default:
        throw UnsupportedError(
          '僅支援 Android，其他平台請重新設定 Firebase。',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCkoTV-Xch5bAQ43joZGqaCUq1DCPPdOT8',
    appId: '1:833102634982:android:e2cdb0dc42c9823a978027',
    messagingSenderId: '833102634982',
    projectId: 'seek-player-f724e',
    storageBucket: 'seek-player-f724e.firebasestorage.app',
  );

  /// Firebase 上的「Seek Player Dev」app(package: com.js.seek_player.dev)。
  static const FirebaseOptions androidDev = FirebaseOptions(
    apiKey: 'AIzaSyCkoTV-Xch5bAQ43joZGqaCUq1DCPPdOT8',
    appId: '1:833102634982:android:5e92112d120cf3b3978027',
    messagingSenderId: '833102634982',
    projectId: 'seek-player-f724e',
    storageBucket: 'seek-player-f724e.firebasestorage.app',
  );
}
