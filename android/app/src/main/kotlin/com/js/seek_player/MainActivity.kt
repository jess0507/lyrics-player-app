package com.js.seek_player

import android.content.Intent
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service / just_audio_background 需要 Activity 繼承 AudioServiceActivity，
// 以提供正確的 FlutterEngine 給背景播放服務。
class MainActivity : AudioServiceActivity() {
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
