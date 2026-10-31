package com.js.seek_player

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

// 把 app 內的音訊檔(選檔器的暫存複本)匯入公用 `Music/Seek Player/`,
// 讓 MediaStore 收錄成一般曲目(Dart 端見 MusicImportService.importFile)。
//
// API 29+ 走 MediaStore insert(RELATIVE_PATH + IS_PENDING),不需任何權限;
// API 24–28 直接寫檔,需 WRITE_EXTERNAL_STORAGE(Dart 端先請求)。
// 兩者最後都 scanFile 並等待完成,確保回傳時 MediaStore 已有時長等欄位,
// Dart 重掃即可看到。回傳實體路徑,失敗回 null。
class MediaImportChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "importAudio" -> {
                    val source = File(call.argument<String>("path")!!)
                    val name = call.argument<String>("displayName")!!
                    executor.execute {
                        val path = try {
                            val imported = importAudio(source, name)
                            scanAndWait(imported)
                            imported
                        } catch (e: Exception) {
                            Log.w(TAG, "importAudio failed: $name", e)
                            null
                        }
                        mainHandler.post { result.success(path) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun importAudio(source: File, name: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
                FOLDER,
            ).apply { mkdirs() }
            val dest = availableFile(dir, name)
            source.copyTo(dest)
            return dest.absolutePath
        }

        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, name)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeTypeOf(name))
            put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MUSIC}/$FOLDER")
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        // 同名檔已存在時 MediaStore 會自動在檔名後加 ` (n)`。
        val uri = resolver.insert(collection, values)
            ?: error("MediaStore insert returned null")
        try {
            resolver.openOutputStream(uri)!!.use { out ->
                source.inputStream().use { it.copyTo(out) }
            }
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) },
                null,
                null,
            )
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        @Suppress("DEPRECATION")
        return resolver.query(uri, arrayOf(MediaStore.Audio.Media.DATA), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
            ?: error("cannot resolve _data for $uri")
    }

    private fun scanAndWait(path: String) {
        val latch = CountDownLatch(1)
        MediaScannerConnection.scanFile(context, arrayOf(path), null) { _, _ -> latch.countDown() }
        latch.await(SCAN_TIMEOUT_SECONDS, TimeUnit.SECONDS)
    }

    // 同名檔已存在時在副檔名前加 ` (n)`,避免覆蓋(API 29+ 由 MediaStore 處理)。
    private fun availableFile(dir: File, name: String): File {
        val dot = name.lastIndexOf('.')
        val stem = if (dot <= 0) name else name.substring(0, dot)
        val ext = if (dot <= 0) "" else name.substring(dot)
        var candidate = File(dir, name)
        var n = 1
        while (candidate.exists()) candidate = File(dir, "$stem (${n++})$ext")
        return candidate
    }

    private fun mimeTypeOf(name: String): String =
        MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(name.substringAfterLast('.', "").lowercase())
            ?.takeIf { it.startsWith("audio/") }
            ?: "audio/mpeg"

    companion object {
        const val CHANNEL_NAME = "seek_player/media_import"
        private const val TAG = "MediaImportChannel"
        private const val FOLDER = "Seek Player"
        private const val SCAN_TIMEOUT_SECONDS = 10L

        // 複製大檔不放主執行緒;共用單一 executor,Activity 重建不會多開。
        private val executor = Executors.newSingleThreadExecutor()
    }
}
