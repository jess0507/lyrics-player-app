package com.js.seek_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * 背景歌詞處理的前景服務:自建 FlutterEngine 跑
 * `lyrics_background_main.dart` 的 `lyricsBackgroundMain`(壓縮 → 上傳 →
 * Cloud Functions),app 從最近工作列滑掉也繼續(不設 stopWithTask,
 * 服務保住 process)。通知列顯示進度,並有「取消」動作按鈕可中止任務。
 *
 * 與 Dart 端的協定見 lyrics_background_protocol.dart:
 * - 啟動 intent 的 EXTRA_REQUEST 為任務 JSON(含已在地化的通知文字),
 *   Dart 端以 getRequest 取回;title / cancelLabel / stepLabels 這裡也
 *   直接從同一份 JSON 解析,不另傳 extras。
 * - Dart 端以 updateNotification 更新進度文字、以 stop 結束服務。
 * - 取消按鈕轉呼 Dart 的 cancel(讓它先回報 main isolate),Dart 再回呼
 *   stop;若 Dart 卡住,CANCEL_GRACE_MS 後強制自停。
 */
class LyricsBackgroundService : Service() {
    companion object {
        private const val TAG = "LyricsBackgroundService"

        const val ACTION_START = "com.js.seek_player.lyrics_background.START"
        const val ACTION_CANCEL = "com.js.seek_player.lyrics_background.CANCEL"
        const val EXTRA_REQUEST = "request"

        private const val METHOD_CHANNEL = "seek_player/lyrics_background"
        private const val CHANNEL_ID = "lyrics_background"
        // 與 just_audio_background 的通知(頻道 com.example.seek_player.audio)
        // 各自獨立;id 避開其預設值。
        private const val NOTIFICATION_ID = 2001

        // 任務結束的結果通知(獨立 id:進度通知隨服務收掉,這則留給使用者滑掉)。
        private const val RESULT_NOTIFICATION_ID = 2002
        private const val TIMEOUT_MS = 20L * 60 * 1000
        private const val CANCEL_GRACE_MS = 5_000L
        private const val DART_ENTRYPOINT_LIBRARY =
            "package:seek_player/features/lyrics/background/lyrics_background_main.dart"
        private const val DART_ENTRYPOINT_FUNCTION = "lyricsBackgroundMain"

        /** 是否有任務執行中(MainActivity 的 launcher channel 據此擋重複啟動)。 */
        @Volatile
        var isRunning = false
            private set

        /**
         * 確保通知頻道存在。獨立成 companion 方法,讓 [MainActivity] 也能在
         * 服務不在(甚至沒啟動過)的情況下,直接發最終確認通知。
         */
        fun ensureChannel(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    // 頻道名稱僅出現在系統設定;比照 main.dart 音訊頻道以固定字串命名。
                    "Lyrics processing",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }

        /**
         * 任務最終確認的結果通知,獨立於服務生命週期之外——main isolate 的
         * `LyricsPendingSyncService` 偵測到 Firestore 轉終態時,經
         * `MainActivity` 的 launcher channel(`notifyResult`)呼叫本方法,
         * 這時前景服務通常早就 stop 了。沿用同一個 [RESULT_NOTIFICATION_ID]
         * 直接覆蓋掉服務結束時貼的「已送出請求」那則。
         */
        fun postResultNotification(context: Context, title: String, text: String) {
            ensureChannel(context)
            val contentIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                PendingIntent.getActivity(context, 3, it, PendingIntent.FLAG_IMMUTABLE)
            }
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(text)
                .setAutoCancel(true)
                .setContentIntent(contentIntent)
                .build()
            context.getSystemService(NotificationManager::class.java)
                .notify(RESULT_NOTIFICATION_ID, notification)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val forceStop = Runnable { stopSelf() }
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var request: String? = null
    private var title = ""
    private var cancelLabel = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand action=${intent?.action} isRunning=$isRunning")
        when (intent?.action) {
            ACTION_START -> if (!isRunning) start(intent) else Unit
            ACTION_CANCEL -> cancel()
        }
        return START_NOT_STICKY
    }

    private fun start(intent: Intent) {
        val raw = intent.getStringExtra(EXTRA_REQUEST) ?: run {
            Log.w(TAG, "start 缺少 request extra,停止服務")
            stopSelf()
            return
        }
        request = raw
        val json = JSONObject(raw)
        title = json.optString("title")
        cancelLabel = json.optString("cancelLabel")
        val initialText = json.optJSONObject("stepLabels")?.optString("compressing") ?: ""

        isRunning = true
        ensureChannel(this)
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(initialText),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
        )
        // 安全網:上傳 / 後端卡死時不讓服務無限期佔用前景。
        mainHandler.postDelayed(forceStop, TIMEOUT_MS)
        Log.i(TAG, "前景服務已啟動 title=$title,建立背景 FlutterEngine")
        startEngine()
    }

    private fun startEngine() {
        // 服務由運行中的 app 啟動,loader 通常已初始化;防禦性補上。
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
        }
        // FlutterEngine 建構時自動註冊 GeneratedPluginRegistrant 的全部
        // plugin(firebase / ffmpeg_kit / isar / on_audio_query …)。
        val engine = FlutterEngine(this)
        this.engine = engine
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRequest" -> result.success(request)
                    "updateNotification" -> {
                        val text = call.argument<String>("text")
                        if (text != null) notify(buildNotification(text))
                        result.success(null)
                    }
                    "stop" -> {
                        // 帶 text 時先發結果通知(成功 / 失敗;取消不帶)再收服務。
                        val text = call.argument<String>("text")
                        Log.i(TAG, "Dart 請求 stop,結束服務(結果通知: ${text != null})")
                        if (text != null) postResultNotification(this@LyricsBackgroundService, title, text)
                        result.success(null)
                        stopSelf()
                    }
                    else -> result.notImplemented()
                }
            }
        }
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                DART_ENTRYPOINT_LIBRARY,
                DART_ENTRYPOINT_FUNCTION,
            ),
        )
    }

    /** 通知列「取消」:先讓 Dart 回報取消並自行請求 stop;逾時則強制停。 */
    private fun cancel() {
        Log.i(TAG, "使用者取消 isRunning=$isRunning")
        val ch = channel
        if (!isRunning || ch == null) {
            stopSelf()
            return
        }
        ch.invokeMethod("cancel", null)
        mainHandler.postDelayed(forceStop, CANCEL_GRACE_MS)
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy:銷毀背景 engine")
        mainHandler.removeCallbacksAndMessages(null)
        channel?.setMethodCallHandler(null)
        channel = null
        // 銷毀 engine 即中止背景 isolate(含進行中的上傳 / callable)。
        engine?.destroy()
        engine = null
        isRunning = false
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun buildNotification(text: String): Notification {
        val cancelIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, LyricsBackgroundService::class.java).setAction(ACTION_CANCEL),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val contentIntent = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 2, it, PendingIntent.FLAG_IMMUTABLE)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentIntent)
            .addAction(0, cancelLabel, cancelIntent)
            .build()
    }

    private fun notify(notification: Notification) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }
}
