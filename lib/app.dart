import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/network/offline_toast_listener.dart';
import 'package:seek_player/core/sync/sync_service.dart';
import 'package:seek_player/core/update/app_update_listener.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_runner.dart';
import 'package:seek_player/features/lyrics/providers/lyrics_pending_sync_service.dart';
import 'package:seek_player/features/player/providers/external_file_open_service.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/router/app_router.dart';
import 'package:seek_player/router/back_button_dispatcher_provider.dart';
import 'package:seek_player/shared/keyboard.dart';
import 'package:seek_player/shared/providers/settings_controller.dart';
import 'package:seek_player/shared/theme/app_theme.dart';

class SeekPlayerApp extends ConsumerWidget {
  const SeekPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 啟動雲端同步（App 啟動 / 登入時依條件上傳或還原）。
    ref.watch(syncServiceProvider);
    // 註冊背景歌詞任務的事件 port:即使任務是上個 app instance 發起
    // (滑掉後由前景服務續跑),完成事件也能刷新歌詞與同步 flag。
    ref.watch(lyricsBackgroundRunnerProvider);
    // 常駐監聽本地待同步的 trackId 清單,狀態轉終態時把結果同步回本機
    // 並移除清單項目,跨 app 重啟也能接續(見 lyricsPendingSyncServiceProvider)。
    ref.watch(lyricsPendingSyncServiceProvider);
    // 接住從檔案管理員等 App「開啟工具」／分享叫進來的音訊檔，見
    // ExternalFileOpenService。
    ref.watch(externalFileOpenServiceProvider);
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);
    // 不用 routerConfig,改分別傳入以換掉返回鍵 dispatcher,
    // 見 SafeRootBackButtonDispatcher。
    final backButtonDispatcher = ref.watch(backButtonDispatcherProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.app_title,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.locale,
      theme: AppTheme.light(settings.seedColor),
      darkTheme: AppTheme.dark(settings.seedColor),
      themeMode: settings.themeMode,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: backButtonDispatcher,
      // 點擊輸入 UI 以外的空白處就收鍵盤(各 TextField 另外用
      // onTapOutside 處理會吃掉手勢的元件,見 dismissKeyboardOnTapOutside)。
      // 更新提示:Google Play 新版本優先,其次 Shorebird patch 重啟提示。
      // 離線提示:各頁面呼叫 ensureOnline 送出的離線事件在此統一顯示 toast。
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: dismissKeyboard,
        child: OfflineToastListener(child: AppUpdateListener(child: child!)),
      ),
    );
  }
}
