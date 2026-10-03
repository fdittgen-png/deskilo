// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the method channel in front of VideoSession (protocol in
// lib/deskilo_video_encoder.dart). One single-thread executor runs every
// call, so frames are appended in order, one at a time, off the UI
// thread; the reply to addFrame is posted only after the frame was
// queued. Detaching cancels every open session and deletes its file.
package de.deskilo.video_encoder

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class DeskiloVideoEncoderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var cacheDir: File
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val sessions = HashMap<Int, VideoSession>()
    private var nextId = 1

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        cacheDir = binding.applicationContext.cacheDir
        channel = MethodChannel(binding.binaryMessenger, "deskilo/video_encoder")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.execute {
            sessions.values.forEach { it.cancel() }
            sessions.clear()
        }
        executor.shutdown()
    }

    private fun ok(result: MethodChannel.Result, value: Any?) {
        main.post { result.success(value) }
    }

    private fun fail(result: MethodChannel.Result, code: String) {
        main.post { result.error(code, null, null) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                handle(call, result)
            } catch (e: VideoSessionException) {
                fail(result, e.code)
            } catch (e: Exception) {
                fail(result, "encode_failed")
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        when (call.method) {
            "probe" -> {
                val supported = VideoSession.supports(width, height)
                ok(result, mapOf("supported" to supported, "reason" to if (supported) null else "unsupported"))
            }
            "start" -> {
                val session = VideoSession(
                    width,
                    height,
                    call.argument<Int>("bitrate") ?: 2_000_000,
                    call.argument<Int>("keyframeIntervalMs") ?: 2000,
                    cacheDir,
                )
                val id = nextId++
                sessions[id] = session
                ok(result, id)
            }
            "addFrame" -> {
                val id = call.argument<Int>("session") ?: -1
                val session = sessions[id] ?: return fail(result, "no_session")
                val rgba = call.argument<ByteArray>("rgba") ?: return fail(result, "bad_args")
                val pts = (call.argument<Number>("ptsMs") ?: return fail(result, "bad_args")).toLong()
                try {
                    session.addFrame(rgba, pts)
                } catch (e: Exception) {
                    session.cancel()
                    sessions.remove(id)
                    throw e
                }
                ok(result, null)
            }
            "finish" -> {
                val id = call.argument<Int>("session") ?: -1
                val session = sessions.remove(id) ?: return fail(result, "no_session")
                val end = (call.argument<Number>("endMs") ?: 0).toLong()
                try {
                    ok(result, session.finish(end, 64 * 1024 * 1024))
                } catch (e: Exception) {
                    session.cancel()
                    throw e
                }
            }
            "cancel" -> {
                val id = call.argument<Int>("session") ?: -1
                sessions.remove(id)?.cancel()
                ok(result, null)
            }
            else -> {
                main.post { result.notImplemented() }
            }
        }
    }
}
