import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/sync/sync_state_store.dart';
import '../providers/track_lyrics_provider.dart';
import 'lyrics_background_running.dart';
// 靜態參照背景進入點,確保其所在 library 被納入 AOT 編譯
// (native 端以函式名啟動,若無任何 import 參照會被整包略過)。
// ignore: unused_import
import 'lyrics_background_main.dart' show lyricsBackgroundMain;
import 'lyrics_background_protocol.dart';

/// 背景任務的最終結果。
enum LyricsBackgroundStatus { success, error, cancelled, busy }

class LyricsBackgroundResult {
  const LyricsBackgroundResult(this.status, [this.errorName, this.activeTitle]);

  final LyricsBackgroundStatus status;

  /// [LyricsBackgroundStatus.error] 時對應 service 錯誤 enum 的 name。
  final String? errorName;

  /// [errorName] 為 busy(後端回報有別首歌正在處理中)時,該曲的曲名。
  final String? activeTitle;
}

/// 追蹤中的單一背景任務(一次只允許一件)。
class _ActiveTask {
  _ActiveTask(this.request, this.onStep);

  final LyricsBackgroundRequest request;
  final void Function(String stepName)? onStep;
  final completer = Completer<LyricsBackgroundResult>();
}

/// main isolate 端的背景歌詞任務入口:
/// - [run] 啟動 LyricsBackgroundService(Android 前景服務)並等待結果,
///   進度經 onStep 回抛給 controller(app 在前景時驅動進度對話框)。
/// - 常駐監聽背景 isolate 的事件 port;即使發起任務的 app instance 已被
///   滑掉、之後重新開啟,done 事件仍會 invalidate 歌詞 provider 並補記
///   同步 flag(背景 isolate 寫的 SharedPreferences 不會反映到 main
///   isolate 的快取,故這裡再 mark 一次,讓 SyncService 能即時推送)。
///
/// app.dart 以 `ref.watch` 令本 provider 隨 app 啟動即註冊事件 port。
class LyricsBackgroundRunner {
  LyricsBackgroundRunner(this._ref) {
    IsolateNameServer.removePortNameMapping(lyricsBackgroundPortName);
    IsolateNameServer.registerPortWithName(
      _port.sendPort,
      lyricsBackgroundPortName,
    );
    final sub = _port.listen((message) {
      if (message is String) {
        _onEvent(LyricsBackgroundEvent.fromJsonString(message));
      }
    });
    _ref.onDispose(() {
      sub.cancel();
      _port.close();
      IsolateNameServer.removePortNameMapping(lyricsBackgroundPortName);
    });
    // app 重啟時校正執行中狀態:任務可能由上一個 app instance 發起,
    // 服務還在跑(iOS 無此 channel,MissingPluginException 靜默略過)。
    _launcher
        .invokeMethod<bool>('isRunning')
        .then((running) {
          if (running == true) _setRunning(true);
        })
        .catchError((_) {});
  }

  static const _launcher = MethodChannel(lyricsBackgroundLauncherChannelName);

  final Ref _ref;
  final _port = ReceivePort();
  _ActiveTask? _active;

  /// 啟動背景任務並等待結果。已有任務在跑(含 native 端判定)回 busy。
  Future<LyricsBackgroundResult> run(
    LyricsBackgroundRequest request, {
    void Function(String stepName)? onStep,
  }) async {
    if (_active != null) {
      return const LyricsBackgroundResult(LyricsBackgroundStatus.busy);
    }
    // Android 13+ 通知權限;拒絕不阻擋任務(服務照跑,只是看不到通知)。
    await Permission.notification.request();

    final task = _ActiveTask(request, onStep);
    _active = task;
    debugPrint(
      '[LyricsBgRunner] 啟動前景服務 mode=${request.mode.name} '
      'trackId=${request.trackId}',
    );
    final started = await _launcher.invokeMethod<bool>(
      'start',
      request.toJsonString(),
    );
    if (started != true) {
      debugPrint('[LyricsBgRunner] 服務已有任務執行中,回報 busy');
      _active = null;
      return const LyricsBackgroundResult(LyricsBackgroundStatus.busy);
    }
    _setRunning(true);
    // 安全網:服務端另有 20 分鐘自停,這裡稍寬,避免服務被系統回收後
    // 呼叫端永遠等不到結果。
    return task.completer.future.timeout(
      const Duration(minutes: 25),
      onTimeout: () {
        _active = null;
        _setRunning(false);
        return const LyricsBackgroundResult(
          LyricsBackgroundStatus.error,
          'unknown',
        );
      },
    );
  }

  void _onEvent(LyricsBackgroundEvent event) {
    debugPrint(
      '[LyricsBgRunner] 事件 ${event.type.name} trackId=${event.trackId}'
      '${event.stepName != null ? ' step=${event.stepName}' : ''}'
      '${event.errorName != null ? ' error=${event.errorName}' : ''}',
    );
    switch (event.type) {
      case LyricsBackgroundEventType.step:
        final step = event.stepName;
        if (step != null) _active?.onStep?.call(step);
      case LyricsBackgroundEventType.done:
        // 不論任務是否由本 app instance 發起都要刷新:結果已由背景
        // isolate 寫入 Isar,這裡讓 UI 重讀並讓 SyncService 立即備份。
        _ref.invalidate(trackLyricsProvider(event.trackId));
        _ref.read(syncStateStoreProvider).markLyricsModified();
        _complete(const LyricsBackgroundResult(LyricsBackgroundStatus.success));
      case LyricsBackgroundEventType.error:
        // 不在此上報 Crashlytics:service 層(compress / upload / callable /
        // 回應解析)已各自上報一次,這裡再報會讓同一次失敗重複兩份。
        _complete(
          LyricsBackgroundResult(
            LyricsBackgroundStatus.error,
            event.errorName,
            event.activeTitle,
          ),
        );
      case LyricsBackgroundEventType.cancelled:
        _complete(
          const LyricsBackgroundResult(LyricsBackgroundStatus.cancelled),
        );
    }
  }

  void _complete(LyricsBackgroundResult result) {
    final task = _active;
    _active = null;
    _setRunning(false);
    if (task != null && !task.completer.isCompleted) {
      task.completer.complete(result);
    }
  }

  void _setRunning(bool value) =>
      _ref.read(lyricsBackgroundRunningProvider.notifier).set(value);

  /// 發 / 更新最終確認通知(同一個原生通知 id,取代前景服務結束時貼的
  /// 「已送出請求」那則)。跟前景服務本身無關,走 app 常駐的 launcher
  /// channel,即使服務早就 stop 了也能呼叫——`LyricsPendingSyncService`
  /// 偵測到 Firestore 轉終態時呼叫。非 Android 無此 channel,
  /// MissingPluginException 靜默略過。
  Future<void> notifyResult({required String title, required String text}) =>
      _launcher
          .invokeMethod<void>('notifyResult', {'title': title, 'text': text})
          .catchError((_) {});
}

final lyricsBackgroundRunnerProvider = Provider<LyricsBackgroundRunner>(
  LyricsBackgroundRunner.new,
);
