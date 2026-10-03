// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — one H.264/MP4 encode with the platform MediaCodec + MediaMuxer.
//
// RGBA frames from the app's off-screen renderer are converted to the
// encoder's YUV 4:2:0 input through the Image API (getInputImage), which
// reports each plane's row and pixel stride, so planar and semi-planar
// encoders are written correctly without guessing a colour format.
// addFrame waits (bounded) for an input buffer while draining output:
// that wait is the backpressure the Dart side awaits. The temporary file
// is this session's: finish() reads it after the muxer stopped and
// deletes it before replying; cancel() releases everything and deletes it.
package de.deskilo.video_encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

class VideoSessionException(val code: String) : Exception(code)

class VideoSession(
    private val width: Int,
    private val height: Int,
    bitrate: Int,
    keyframeIntervalMs: Int,
    directory: File,
) {
    companion object {
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val TIMEOUT_US = 10_000L
        private const val MAX_WAIT_LOOPS = 1_000

        fun format(width: Int, height: Int, bitrate: Int, keyframeIntervalMs: Int): MediaFormat =
            MediaFormat.createVideoFormat(MIME, width, height).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, 10)
                setFloat(MediaFormat.KEY_I_FRAME_INTERVAL, keyframeIntervalMs / 1000f)
            }

        fun supports(width: Int, height: Int): Boolean {
            if (width <= 0 || height <= 0 || width % 2 != 0 || height % 2 != 0) return false
            if (width > 1920 || height > 1920) return false
            val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            return list.findEncoderForFormat(format(width, height, 2_000_000, 2000)) != null
        }
    }

    val file: File = File.createTempFile("deskilo-video-", ".mp4", directory)
    private val codec: MediaCodec
    private val muxer: MediaMuxer
    private val info = MediaCodec.BufferInfo()
    private var track = -1
    private var muxing = false
    private var lastPtsUs = -1L
    private var released = false

    init {
        if (!supports(width, height)) {
            file.delete()
            throw VideoSessionException("unsupported")
        }
        val fmt = format(width, height, bitrate, keyframeIntervalMs)
        val name = MediaCodecList(MediaCodecList.REGULAR_CODECS).findEncoderForFormat(fmt)
        codec = MediaCodec.createByCodecName(name)
        try {
            codec.configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        } catch (e: Exception) {
            codec.release()
            file.delete()
            throw VideoSessionException("unsupported")
        }
    }

    fun addFrame(rgba: ByteArray, ptsMs: Long) {
        val ptsUs = ptsMs * 1000
        if (rgba.size != width * height * 4 || ptsUs <= lastPtsUs) {
            throw VideoSessionException("bad_args")
        }
        val index = dequeueInput()
        val image = codec.getInputImage(index) ?: throw VideoSessionException("encode_failed")
        writeYuv(image, rgba)
        codec.queueInputBuffer(index, 0, width * height * 3 / 2, ptsUs, 0)
        lastPtsUs = ptsUs
        drain(false)
    }

    /** Ends the stream at [endMs], stops the muxer, returns the MP4 bytes. */
    fun finish(endMs: Long, maxBytes: Int): ByteArray {
        val index = dequeueInput()
        val endUs = maxOf(endMs * 1000, lastPtsUs + 1)
        codec.queueInputBuffer(index, 0, 0, endUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(true)
        try {
            if (!muxing) throw VideoSessionException("finalize_failed")
            muxer.stop()
        } catch (e: IllegalStateException) {
            throw VideoSessionException("finalize_failed")
        } finally {
            release()
        }
        val bytes = file.readBytes()
        file.delete()
        if (bytes.isEmpty()) throw VideoSessionException("finalize_failed")
        if (bytes.size > maxBytes) throw VideoSessionException("too_large")
        return bytes
    }

    fun cancel() {
        release()
        file.delete()
    }

    private fun release() {
        if (released) return
        released = true
        try { codec.stop() } catch (e: Exception) { /* already stopped */ }
        codec.release()
        try { if (muxing) muxer.stop() } catch (e: Exception) { /* nothing written */ }
        muxer.release()
    }

    private fun dequeueInput(): Int {
        repeat(MAX_WAIT_LOOPS) {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index >= 0) return index
            drain(false)
        }
        throw VideoSessionException("encode_failed")
    }

    private fun drain(endOfStream: Boolean) {
        var idle = 0
        while (true) {
            val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                    if (++idle > MAX_WAIT_LOOPS) throw VideoSessionException("finalize_failed")
                }
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (muxing) throw VideoSessionException("encode_failed")
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxing = true
                }
                index >= 0 -> {
                    val buffer = codec.getOutputBuffer(index)
                        ?: throw VideoSessionException("encode_failed")
                    val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (!config && info.size > 0 && muxing) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    /** BT.601 limited-range RGBA → YUV 4:2:0 into the encoder's planes. */
    private fun writeYuv(image: android.media.Image, rgba: ByteArray) {
        val planes = image.planes
        val y = planes[0]
        val u = planes[1]
        val v = planes[2]
        val yBuf = y.buffer
        val uBuf = u.buffer
        val vBuf = v.buffer
        for (row in 0 until height) {
            for (col in 0 until width) {
                val o = (row * width + col) * 4
                val r = rgba[o].toInt() and 0xff
                val g = rgba[o + 1].toInt() and 0xff
                val b = rgba[o + 2].toInt() and 0xff
                val luma = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yBuf.put(row * y.rowStride + col * y.pixelStride, luma.toByte())
                if (row % 2 == 0 && col % 2 == 0) {
                    val cb = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val cr = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    val cr2 = row / 2
                    val cc = col / 2
                    uBuf.put(cr2 * u.rowStride + cc * u.pixelStride, cb.toByte())
                    vBuf.put(cr2 * v.rowStride + cc * v.pixelStride, cr.toByte())
                }
            }
        }
    }
}
