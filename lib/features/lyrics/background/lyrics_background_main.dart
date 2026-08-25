import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seek_player/core/crash_reporter.dart';
import 'package:seek_player/core/storage/isar_service.dart';
import 'package:seek_player/core/storage/preferences_service.dart';
import 'package:seek_player/firebase_options.dart';
import 'package:seek_player/features/lyrics/auto_generate/lyrics_auto_generate_service.dart';
import 'package:seek_player/features/lyrics/auto_sync/lyrics_auto_sync_service.dart';
import 'package:seek_player/features/lyrics/background/lyrics_background_protocol.dart';

/// LyricsBackgroundService(Android 前景服務)專用的 Dart 進入點:
/// 服務建立獨立 FlutterEngine 後執行本函式,在背景 isolate 重建
/// Firebase / Isar / Riverpod 環境並跑歌詞 pipeline,app 從最近工作列
/// 滑掉也不中斷(process 由前景服務保活,main isolate 死掉不影響)。
///
/// 與 main isolate 的溝通見 [lyrics_background_protocol.dart] 的說明。
@pragma('vm:entry-point')
Future<void> lyricsBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(lyricsBackgroundServiceChannelName);

  final raw = await channel.invokeMethod<String>('getRequest');
  if (raw == null) {
    debugPrint('[LyricsBg] 服務未提供 request,直接停止');
    await channel.invokeMethod<void>('stop');
    return;
  }
  final request = LyricsBackgroundRequest.fromJsonString(raw);
  debugPrint(
    '[LyricsBg] 背景 isolate 啟動 mode=${request.mode.name} '
    'trackId=${request.trackId} title="${request.title}"',
  );

  void emit(
    LyricsBackgroundEventType type, {
    String? stepName,
    String? errorName,
    String? activeTitle,
  }) {
    // main isolate 不在(app 已被滑掉)時 port 查無,靜默略過;
    // 結果已寫入 Isar,下次開 app 自然讀到。
    IsolateNameServer.lookupPortByName(lyricsBackgroundPortName)?.send(
      LyricsBackgroundEvent(
        type: type,
        mode: request.mode,
        trackId: request.trackId,
        stepName: stepName,
        errorName: errorName,
        activeTitle: activeTitle,
      ).toJsonString(),
    );
  }

  // 通知列的「取消」按鈕:native 端轉呼本 handler。回報後請服務自停,
  // 服務 onDestroy 會銷毀本 engine,進行中的上傳 / callable 隨之中止。
  channel.setMethodCallHandler((call) async {
    if (call.method == 'cancel') {
      debugPrint('[LyricsBg] 收到取消,回報後請服務自停');
      emit(LyricsBackgroundEventType.cancelled);
      await channel.invokeMethod<void>('stop');
    }
  });

  // 服務由運行中的 app 啟動,native Firebase 必已初始化;此處是讓
  // 「本 isolate 的 Dart 端」接上既有的 default app。App Check provider
  // 為 process 級單例,main isolate 啟動時已 activate,不需重做。
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // 已初始化(duplicate-app)等情況;pipeline 內的呼叫會自行暴露真正問題。
  }

  // 新 isolate 的 FirebaseAuth 要等第一次 auth state 事件才會載入
  // currentUser;不等的話 pipeline 會把已登入者誤判成未登入。
  try {
    await FirebaseAuth.instance.authStateChanges().first.timeout(
      const Duration(seconds: 10),
    );
  } on TimeoutException {
    // 逾時放行,交由 pipeline 的未登入檢查決定結果。
    debugPrint('[LyricsBg] 等待 auth state 逾時');
  }
  debugPrint('[LyricsBg] auth uid=${FirebaseAuth.instance.currentUser?.uid}');

  final prefs = await PreferencesService.create();
  final isar = await openIsar();
  debugPrint('[LyricsBg] Isar 已開啟,開始執行 pipeline');
  final container = ProviderContainer(
    overrides: [
      preferencesServiceProvider.overrideWithValue(prefs),
      isarProvider.overrideWithValue(isar),
    ],
  );

  void onStep(String stepName) {
    debugPrint('[LyricsBg] step=$stepName');
    emit(LyricsBackgroundEventType.step, stepName: stepName);
    channel.invokeMethod<void>('updateNotification', {
      'text': request.stepLabels[stepName],
    });
  }

  // 結束時要顯示的結果通知文字;成功 / 失敗各異,取消(null)不發。
  String? resultText;
  try {
    switch (request.mode) {
      case LyricsBackgroundMode.generate:
        await container
            .read(lyricsAutoGenerateServiceProvider)
            .generate(
              trackId: request.trackId,
              title: request.title,
              onStep: (step) => onStep(step.name),
            );
      case LyricsBackgroundMode.align:
        await container
            .read(lyricsAutoSyncServiceProvider)
            .autoSync(
              trackId: request.trackId,
              title: request.title,
              language: request.language ?? '',
              engine: LyricsAlignEngine.values.byName(
                request.engineName ?? LyricsAlignEngine.aeneas.name,
              ),
              onStep: (step) => onStep(step.name),
            );
    }
    debugPrint('[LyricsBg] 完成 trackId=${request.trackId}');
    resultText = request.doneLabel;
    emit(LyricsBackgroundEventType.done);
  } on LyricsAutoGenerateException catch (e) {
    debugPrint('[LyricsBg] 失敗(generate): ${e.error.name}');
    resultText = request.failedLabel;
    emit(
      LyricsBackgroundEventType.error,
      errorName: e.error.name,
      activeTitle: e.activeTitle,
    );
  } on LyricsAutoSyncException catch (e) {
    debugPrint('[LyricsBg] 失敗(align): ${e.error.name}');
    resultText = request.failedLabel;
    emit(
      LyricsBackgroundEventType.error,
      errorName: e.error.name,
      activeTitle: e.activeTitle,
    );
  } catch (e, s) {
    reportError(e, s, reason: '背景歌詞處理：未預期錯誤');
    resultText = request.failedLabel;
    emit(LyricsBackgroundEventType.error, errorName: 'unknown');
  } finally {
    container.dispose();
    // 取消流程可能已請 stop、服務已收掉,channel 呼叫失敗屬預期。
    try {
      await channel.invokeMethod<void>('stop', {'text': resultText});
    } catch (_) {}
  }
}
