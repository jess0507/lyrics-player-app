package com.js.seek_player

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * 音檔全檔內容的 SHA-256(64 碼小寫 hex),即曲目身份 trackId。
 *
 * 用系統的 MessageDigest(Conscrypt / BoringSSL),會用到 ARMv8 SHA 硬體指令,
 * 比 Dart 端的 package:crypto 快一個數量級。在背景執行緒讀檔計算,不卡主執行緒;
 * 結果與後端 `hashlib.sha256(file_bytes).hexdigest()` 相同。
 */
class FileHashChannel(messenger: BinaryMessenger) {
    // 讀檔為主(I/O bound),兩條執行緒就夠;Dart 端也會限制同時請求的數量。
    private val executor = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sha256" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        // 讀不到檔案(不存在 / 無權限)回 null。
                        val hash = runCatching { fileSha256(path) }.getOrNull()
                        mainHandler.post { result.success(hash) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        const val CHANNEL = "seek_player/file_hash"

        fun fileSha256(path: String): String {
            val md = MessageDigest.getInstance("SHA-256")
            File(path).inputStream().use { input ->
                val buf = ByteArray(1 shl 20)
                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    md.update(buf, 0, n)
                }
            }
            val hex = StringBuilder(64)
            for (b in md.digest()) {
                val v = b.toInt() and 0xff
                hex.append(HEX[v ushr 4]).append(HEX[v and 0x0f])
            }
            return hex.toString()
        }

        private val HEX = "0123456789abcdef".toCharArray()
    }
}
