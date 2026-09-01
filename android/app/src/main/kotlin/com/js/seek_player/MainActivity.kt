package com.js.seek_player

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service / just_audio_background 需要 Activity 繼承 AudioServiceActivity，
// 以提供正確的 FlutterEngine 給背景播放服務。
class MainActivity : AudioServiceActivity() {
    // 無邊框(edge-to-edge):在 Flutter 首幀之前就由原生端開啟,不依賴 Dart 端
    // main() 的執行時機。Android 15+ 由系統強制;以下版本靠這裡加上
    // FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS(引擎只在 API<30 自行補),
    // 系統列顏色才吃得到 styles.xml / SystemChrome 設的透明值。
    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS or
                WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 背景歌詞處理:Dart 端(lyrics_background_runner.dart)由此啟動
        // LyricsBackgroundService。一次僅允許一件任務,重複啟動回 false。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seek_player/lyrics_background_launcher",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (LyricsBackgroundService.isRunning) {
                        result.success(false)
                    } else {
                        val intent = Intent(this, LyricsBackgroundService::class.java)
                            .setAction(LyricsBackgroundService.ACTION_START)
                            .putExtra(LyricsBackgroundService.EXTRA_REQUEST, call.arguments as String)
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    }
                }
                "isRunning" -> result.success(LyricsBackgroundService.isRunning)
                "cancel" -> {
                    // app 內取消按鈕:效果等同使用者按下通知列的取消動作。
                    // 服務沒在跑就什麼都不做(本機工作早就結束了)。
                    if (LyricsBackgroundService.isRunning) {
                        startService(
                            Intent(this, LyricsBackgroundService::class.java)
                                .setAction(LyricsBackgroundService.ACTION_CANCEL),
                        )
                    }
                    result.success(null)
                }
                "notifyResult" -> {
                    // main isolate 常駐呼叫,跟前景服務生命週期無關(通常服務
                    // 早就 stop 了)——LyricsPendingSyncService 偵測到
                    // Firestore 轉終態時用來發最終確認通知。
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title") as? String ?: ""
                    val text = args?.get("text") as? String ?: ""
                    LyricsBackgroundService.postResultNotification(this, title, text)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
