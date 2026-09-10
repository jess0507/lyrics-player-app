package com.js.seek_player

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// 接住從檔案管理員「開啟工具」(ACTION_VIEW)或分享面板(ACTION_SEND)
// 叫進來的音訊檔,整理成 Dart 端(ExternalFileOpenService)要的 map:
// uri / displayName / title / artist / album / durationMs / filePath。
///
// 一律由 Dart 主動拉取:Dart 建立 service 時(冷啟動)與每次回到前景時呼叫
// `takeLaunchIntent`,這裡回傳 `describe(activity.intent)` 並立刻把
// activity.intent 的 action / data 清掉,避免之後重播。
// 之所以不在這裡主動推送:audio_service 會快取 FlutterEngine,使用者滑掉 app
// 後 Dart 仍活著,再從檔案開 app 只會重建 Activity(重跑 configureFlutterEngine)
// 而不重跑 Dart main(),此時 Dart 端沒有任何「重新初始化」的時機可以接推送;
// 改由 Dart 在 onResume 拉,冷啟動 / 背景重建 / 前景 onNewIntent 三種情境
// 都走同一條路。
// 從最近使用重開時系統會重送原始 intent(帶 FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY),
// 一律略過。
class ExternalOpenChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeLaunchIntent" -> {
                    // 在主執行緒同步「取走」intent,連續兩次呼叫(建立時 + 首次
                    // resume)只有第一次拿得到,不會重播。
                    val launch = activity.intent
                    activity.intent = consumed(launch)
                    executor.execute {
                        val described = describe(launch)
                        mainHandler.post { result.success(described) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // singleTask 下 app 已存在時再開一個檔會走這裡;只要設成 activity.intent,
    // 緊接著的 onResume 會讓 Dart 來拉。
    fun onNewIntent(intent: Intent) {
        activity.intent = intent
    }

    // 保留原 intent 的 flags / extras(FlutterActivity 會讀),只清掉會被
    // describe() 認成外部開檔的 action / data / type / EXTRA_STREAM。
    private fun consumed(intent: Intent?): Intent {
        val base = if (intent == null) Intent() else Intent(intent)
        return base
            .setAction(Intent.ACTION_MAIN)
            .setDataAndType(null, null)
            .apply { removeExtra(Intent.EXTRA_STREAM) }
    }

    // 純函式:intent 不是我們要接的音訊檔就回 null。
    private fun describe(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> streamExtra(intent)
            else -> null
        } ?: return null
        // resolveType 與系統比對 intent-filter 用的邏輯一致:
        // 有明示 type 用 type,否則向 content provider 問。
        val type = intent.resolveType(activity.contentResolver) ?: return null
        if (!type.startsWith("audio/")) return null

        val meta = readMetadata(uri)
        return mapOf(
            "uri" to uri.toString(),
            "displayName" to queryDisplayName(uri),
            "title" to meta.title,
            "artist" to meta.artist,
            "album" to meta.album,
            "durationMs" to meta.durationMs,
            "filePath" to resolvePath(uri),
        )
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        intent.getParcelableExtra(Intent.EXTRA_STREAM)

    private fun queryDisplayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        return queryString(uri, OpenableColumns.DISPLAY_NAME, null, null)
    }

    private data class Metadata(
        val title: String?,
        val artist: String?,
        val album: String?,
        val durationMs: Long?,
    )

    private fun readMetadata(uri: Uri): Metadata {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(activity, uri)
            Metadata(
                title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                    ?.takeIf { it.isNotBlank() },
                artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    ?.takeIf { it.isNotBlank() },
                album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                    ?.takeIf { it.isNotBlank() },
                durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull(),
            )
        } catch (_: Exception) {
            Metadata(null, null, null, null)
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
    }

    // ---- 實體路徑還原(不複製檔案),依序嘗試,第一個存在的檔案勝出 ----

    private fun resolvePath(uri: Uri): String? {
        val candidates = sequence {
            // 1. file://
            if (uri.scheme == "file") yield(uri.path)
            if (uri.scheme == "content") {
                // 2. 任何 content URI 直接問 _data(MediaStore 與部分檔案管理員支援)
                yield(queryData(uri, null, null))
                // 3–5. 系統 DocumentsProvider
                if (DocumentsContract.isDocumentUri(activity, uri)) {
                    val docId = runCatching { DocumentsContract.getDocumentId(uri) }.getOrNull()
                    if (docId != null) {
                        when (uri.authority) {
                            AUTHORITY_EXTERNAL_STORAGE -> yield(externalStoragePath(docId))
                            AUTHORITY_MEDIA -> yield(mediaDocumentPath(docId))
                            AUTHORITY_DOWNLOADS -> yield(downloadsDocumentPath(docId))
                        }
                    }
                }
                // 6. 其餘 provider:DISPLAY_NAME + SIZE 反查 MediaStore audio
                yield(lookupByNameAndSize(uri))
            }
        }
        return candidates
            .filterNotNull()
            .firstOrNull { it.isNotEmpty() && runCatching { File(it).exists() }.getOrDefault(false) }
    }

    // `primary:Music/a.mp3` → `/storage/emulated/0/Music/a.mp3`;
    // `<uuid>:path` → `/storage/<uuid>/path`。
    @Suppress("DEPRECATION")
    private fun externalStoragePath(docId: String): String? {
        val sep = docId.indexOf(':')
        if (sep < 0) return null
        val volume = docId.substring(0, sep)
        val relative = docId.substring(sep + 1)
        val root = when (volume) {
            "primary" -> Environment.getExternalStorageDirectory().absolutePath
            "home" -> File(
                Environment.getExternalStorageDirectory(),
                Environment.DIRECTORY_DOCUMENTS,
            ).absolutePath
            else -> "/storage/$volume"
        }
        return if (relative.isEmpty()) root else "$root/$relative"
    }

    // `audio:1234` → 查 MediaStore.Audio `_ID = 1234` 的 `_data`。
    private fun mediaDocumentPath(docId: String): String? {
        val sep = docId.indexOf(':')
        if (sep < 0) return null
        if (docId.substring(0, sep) != "audio") return null
        val id = docId.substring(sep + 1).toLongOrNull() ?: return null
        return queryData(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            "${MediaStore.Audio.Media._ID} = ?",
            arrayOf(id.toString()),
        )
    }

    // `raw:/path` 直接用;`msf:<id>` 查 MediaStore.Files;
    // 純數字 id 查 `content://downloads/public_downloads/<id>`。
    private fun downloadsDocumentPath(docId: String): String? {
        if (docId.startsWith("raw:")) return docId.removePrefix("raw:")
        if (docId.startsWith("msf:")) {
            val id = docId.removePrefix("msf:").toLongOrNull() ?: return null
            return queryData(
                MediaStore.Files.getContentUri("external"),
                "${MediaStore.Files.FileColumns._ID} = ?",
                arrayOf(id.toString()),
            )
        }
        val id = docId.toLongOrNull() ?: return null
        return queryData(
            ContentUris.withAppendedId(Uri.parse("content://downloads/public_downloads"), id),
            null,
            null,
        )
    }

    // 以 DISPLAY_NAME + SIZE 查 MediaStore audio,唯一命中才採用。
    private fun lookupByNameAndSize(uri: Uri): String? {
        var name: String? = null
        var size: Long? = null
        try {
            activity.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { c ->
                if (c.moveToFirst()) {
                    val nameIdx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIdx = c.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIdx >= 0 && !c.isNull(nameIdx)) name = c.getString(nameIdx)
                    if (sizeIdx >= 0 && !c.isNull(sizeIdx)) size = c.getLong(sizeIdx)
                }
            }
        } catch (_: Exception) {
            return null
        }
        val n = name ?: return null
        val s = size ?: return null
        return try {
            activity.contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                arrayOf(DATA_COLUMN),
                "${MediaStore.Audio.Media.DISPLAY_NAME} = ? AND ${MediaStore.Audio.Media.SIZE} = ?",
                arrayOf(n, s.toString()),
                null,
            )?.use { c ->
                if (c.count != 1 || !c.moveToFirst()) return null
                val idx = c.getColumnIndex(DATA_COLUMN)
                if (idx >= 0 && !c.isNull(idx)) c.getString(idx) else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun queryData(uri: Uri, selection: String?, args: Array<String>?): String? =
        queryString(uri, DATA_COLUMN, selection, args)

    private fun queryString(
        uri: Uri,
        column: String,
        selection: String?,
        args: Array<String>?,
    ): String? = try {
        activity.contentResolver.query(uri, arrayOf(column), selection, args, null)?.use { c ->
            if (!c.moveToFirst()) return null
            val idx = c.getColumnIndex(column)
            if (idx >= 0 && !c.isNull(idx)) c.getString(idx) else null
        }
    } catch (_: Exception) {
        // 非 MediaStore 的 provider 不認得 _data 會丟 IllegalArgumentException,
        // 也可能因權限丟 SecurityException;都當作查不到。
        null
    }

    companion object {
        const val CHANNEL_NAME = "seek_player/external_open"

        // ContentResolver 查詢 + MediaMetadataRetriever 讀 tag 可能要幾百 ms,
        // 不放主執行緒。放 companion 共用:Activity 重建會 new 一個新的
        // ExternalOpenChannel,避免每次都多留一條 thread。
        private val executor = Executors.newSingleThreadExecutor()

        private const val AUTHORITY_EXTERNAL_STORAGE = "com.android.externalstorage.documents"
        private const val AUTHORITY_MEDIA = "com.android.providers.media.documents"
        private const val AUTHORITY_DOWNLOADS = "com.android.providers.downloads.documents"

        @Suppress("DEPRECATION")
        private const val DATA_COLUMN = MediaStore.MediaColumns.DATA
    }
}
