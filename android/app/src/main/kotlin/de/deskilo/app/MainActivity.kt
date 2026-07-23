package de.deskilo.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Kiosk pinning: while kiosk mode is confirmed the app pins
        // itself (screen pinning / lock task) so the pad cannot leave
        // it — home, recents and notifications are blocked by the
        // system. Best-effort: without device-owner provisioning Android
        // shows its one-time pinning confirmation.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "deskilo/kiosk",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "lock" -> result.success(
                    runCatching { startLockTask() }.isSuccess,
                )
                "unlock" -> result.success(
                    runCatching { stopLockTask() }.isSuccess,
                )
                else -> result.notImplemented()
            }
        }
        // Local-save channel: exports (bill/badge/config PDFs, XML) land
        // in the USER-VISIBLE Downloads collection via MediaStore — no
        // runtime permission needed on API 29+. Pre-29 falls back to the
        // public Downloads directory (legacy external storage).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "deskilo/downloads",
        ).setMethodCallHandler { call, result ->
            if (call.method != "save") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val fileName = call.argument<String>("fileName")
            val bytes = call.argument<ByteArray>("bytes")
            val mimeType = call.argument<String>("mimeType")
                ?: "application/octet-stream"
            if (fileName == null || bytes == null) {
                result.error("bad_args", "fileName and bytes required", null)
                return@setMethodCallHandler
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val values = ContentValues().apply {
                        put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                        put(MediaStore.Downloads.MIME_TYPE, mimeType)
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
                    val resolver = contentResolver
                    val uri = resolver.insert(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI, values,
                    ) ?: throw IllegalStateException("MediaStore insert failed")
                    resolver.openOutputStream(uri)?.use { it.write(bytes) }
                        ?: throw IllegalStateException("openOutputStream failed")
                    values.clear()
                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                    result.success(
                        "${Environment.DIRECTORY_DOWNLOADS}/$fileName",
                    )
                } else {
                    @Suppress("DEPRECATION")
                    val dir = Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_DOWNLOADS,
                    )
                    dir.mkdirs()
                    val file = File(dir, fileName)
                    file.writeBytes(bytes)
                    result.success(file.absolutePath)
                }
            } catch (e: Exception) {
                result.error("save_failed", e.message, null)
            }
        }
    }
}
