import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show FlutterError, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:seek_player/features/playlists/services/playlist_repository.dart';

import 'package:seek_player/app.dart';
import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/firebase_available_provider.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/core/storage/track_id_cleanup.dart';
import 'package:seek_player/core/sync/sync_state_store.dart';
import 'package:seek_player/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 無邊框(edge-to-edge)顯示：targetSdk 36 讓 Android 15+ 由系統強制開啟，
  // 但 Android 14 以下不會，Play Console 會警告「不會向所有使用者顯示無邊框
  // 畫面」。這裡明確開啟並把系統列塗成透明，讓各版本表現一致。
  // (Android 15+ 已忽略 statusBarColor / navigationBarColor，僅對舊版生效。)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // 背景播放 / 通知列控制。
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.seek_player.audio',
    androidNotificationChannelName: 'Lyrics Player',
    androidNotificationOngoing: true,
  );

  // Firebase 初始化失敗（未設定 / 無網路）時不應阻擋 App 啟動。
  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // App Check:後端 callable(generate_lyrics / align_lyrics)有開
    // enforcement,未送有效 token 會被映成 UNAVAILABLE。release 走平台
    // attestation,debug build 走 debug provider(需在 Firebase Console
    // 註冊裝置印出的 debug token 才能通過)。
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestProvider()
          : const AppleDebugProvider(),
    );

    // Crashlytics:debug build 不上報以免污染資料,release 才收集。
    // Flutter 框架同步錯誤與非同步(PlatformDispatcher)錯誤都轉送。
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // 回報帶上登入使用者的 uid,方便在 Crashlytics 對回特定帳號。
    bindCrashUserIdentifier();

    firebaseAvailable = true;
  } catch (e) {
    debugPrint('Firebase 初始化失敗，帳戶功能停用：$e');
  }

  final prefs = await PreferencesService.create();
  final isar = await openIsar();
  final syncState = SyncStateStore(prefs);

  // 清掉指紋化(sync v5)前留下的舊資料——trackId 非 sha1 hash 格式一律視為
  // 過期資料;只跑一次。
  await cleanupNonHashTrackIds(isar: isar, prefs: prefs, syncState: syncState);

  // 確保預設「我的最愛」/「最近播放」清單存在(DB 內存名僅作 fallback,
  // UI 顯示在地化名稱)。
  final playlistRepository = PlaylistRepository(isar, syncState);
  await playlistRepository.ensureDefaultFavorites();
  await playlistRepository.ensureDefaultRecentlyPlayed();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefs),
        isarProvider.overrideWithValue(isar),
        firebaseAvailableProvider.overrideWithValue(firebaseAvailable),
      ],
      child: const SeekPlayerApp(),
    ),
  );
}
