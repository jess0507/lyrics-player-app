import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/sync_service.dart';
import 'core/update/app_update_listener.dart';
import 'features/lyrics/background/lyrics_background_runner.dart';
import 'features/lyrics/providers/lyrics_pending_sync_service.dart';
import 'features/player/providers/external_file_open_service.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'shared/providers/settings_controller.dart';
import 'shared/theme/app_theme.dart';

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

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.app_title,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.locale,
      theme: AppTheme.light(settings.seedColor),
      darkTheme: AppTheme.dark(settings.seedColor),
      themeMode: settings.themeMode,
      routerConfig: router,
      // 更新提示:Google Play 新版本優先,其次 Shorebird patch 重啟提示。
      builder: (context, child) => AppUpdateListener(child: child!),
    );
  }
}
