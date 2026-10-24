// SPDX-License-Identifier: AGPL-3.0-or-later
package de.deskilo.app

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.ViewGroup
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * #2559 C1 — the app-switcher privacy cover on Android.
 *
 * Dart (channel `deskilo/switcher_cover`) says what the window shows:
 * `setProtectedContext(protected, frameEpoch)` and, once that frame is on
 * screen, `foregroundReady(frameEpoch)`. Nothing private crosses: this
 * keeps the protection, the current frame epoch, whether the activity is
 * resumed and whether the cover is up.
 *
 * - API 33+: `setRecentsScreenshotEnabled(false)` while protected, so the
 *   recents preview is blank. No FLAG_SECURE: screenshots stay allowed.
 * - Every level: on pause, an opaque neutral view (the launch background:
 *   theme canvas and the app mark) over the whole window, matching its
 *   bounds through rotation and resize. On resume it stays until the
 *   CURRENT frame is acknowledged; a stale epoch never lifts it.
 *
 * It starts protected with no frame, so a cover raised before Dart spoke
 * waits for a real acknowledgement.
 */
class SwitcherCover(private val activity: Activity) {
    private var protectedContext = true
    private var frameEpoch = NO_FRAME
    private var resumed = false
    private var cover: View? = null

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setProtectedContext" -> {
                    val protect = call.argument<Boolean>("protected")
                    val epoch = call.argument<Number>("frameEpoch")?.toLong()
                    if (protect == null || epoch == null) {
                        result.error("bad_args", "protected and frameEpoch required", null)
                    } else {
                        setProtectedContext(protect, epoch)
                        result.success(null)
                    }
                }
                "foregroundReady" -> {
                    val epoch = call.argument<Number>("frameEpoch")?.toLong()
                    if (epoch == null) {
                        result.error("bad_args", "frameEpoch required", null)
                    } else {
                        foregroundReady(epoch)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        applyRecentsPolicy()
    }

    private fun setProtectedContext(protect: Boolean, epoch: Long) {
        protectedContext = protect
        frameEpoch = epoch
        applyRecentsPolicy()
        // Nothing to hide any more, and the person is looking: lift it.
        if (!protect && resumed) hide()
    }

    private fun foregroundReady(epoch: Long) {
        // Only the current frame, drawn while in the foreground, lifts it.
        if (resumed && epoch == frameEpoch) hide()
    }

    /** Before the activity's own onPause: the cover is in the last frame. */
    fun onPause() {
        resumed = false
        if (protectedContext) show()
    }

    /** Before the activity's own onResume. */
    fun onResume() {
        resumed = true
        if (!protectedContext) hide()
    }

    private fun applyRecentsPolicy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.setRecentsScreenshotEnabled(!protectedContext)
        }
    }

    private fun show() {
        if (cover != null) return
        val root = activity.window?.decorView as? ViewGroup ?: return
        val view = View(activity).apply {
            setBackgroundResource(R.drawable.launch_background)
            // Swallow touches: nothing under the cover reacts to a tap.
            isClickable = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        }
        root.addView(
            view,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        cover = view
    }

    private fun hide() {
        val view = cover ?: return
        (view.parent as? ViewGroup)?.removeView(view)
        cover = null
    }

    companion object {
        const val CHANNEL = "deskilo/switcher_cover"
        private const val NO_FRAME = -1L
    }
}
