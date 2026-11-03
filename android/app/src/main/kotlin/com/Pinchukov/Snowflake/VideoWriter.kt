package com.Pinchukov.Snowflake

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Writes an MP4 (H.264, no sound) from RGBA frames sent one by one over the
 * channel: "start" (path, width, height, fps, bitrate), a "frame" per frame,
 * then "finish". The work is done off the main thread, in order.
 */
class VideoWriter private constructor(
    path: String,
    private val width: Int,
    private val height: Int,
    private val fps: Int,
    bitrate: Int,
) {
    private val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private val info = MediaCodec.BufferInfo()
    private var track = -1
    private var frames = 0L

    init {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
    }

    private fun frame(rgba: ByteArray) {
        val i = input()
        val image = codec.getInputImage(i)!!
        // BT.601, video range; colour from each 2 × 2 block's average. Worked
        // out in arrays a row at a time, each row then put in one go when
        // its plane packs it tight.
        val (yp, up, vp) = image.planes
        val yRow = ByteArray(width)
        val uRow = ByteArray(width / 2)
        val vRow = ByteArray(width / 2)
        for (row in 0 until height) {
            var p = row * width * 4
            for (col in 0 until width) {
                val r = rgba[p].toInt() and 0xFF
                val g = rgba[p + 1].toInt() and 0xFF
                val b = rgba[p + 2].toInt() and 0xFF
                yRow[col] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte()
                p += 4
            }
            putRow(yp, row, yRow)
            if (row % 2 == 1) continue
            for (col in 0 until width / 2) {
                val p0 = (row * width + col * 2) * 4
                val p1 = p0 + width * 4
                fun sum(c: Int) = (rgba[p0 + c].toInt() and 0xFF) + (rgba[p0 + 4 + c].toInt() and 0xFF) +
                    (rgba[p1 + c].toInt() and 0xFF) + (rgba[p1 + 4 + c].toInt() and 0xFF)
                val r = sum(0) / 4
                val g = sum(1) / 4
                val b = sum(2) / 4
                uRow[col] = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte()
                vRow[col] = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte()
            }
            putRow(up, row / 2, uRow)
            putRow(vp, row / 2, vRow)
        }
        codec.queueInputBuffer(i, 0, width * height * 3 / 2, frames++ * 1_000_000L / fps, 0)
        drain(false)
    }

    /** Puts [values] as [plane]'s row [row]: in one go if it packs them tight. */
    private fun putRow(plane: Image.Plane, row: Int, values: ByteArray) {
        val buf = plane.buffer
        val at = row * plane.rowStride
        if (plane.pixelStride == 1) {
            buf.position(at)
            buf.put(values)
        } else {
            for (i in values.indices) buf.put(at + i * plane.pixelStride, values[i])
        }
    }

    private fun finish() {
        codec.queueInputBuffer(input(), 0, 0, frames * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(true)
        codec.stop()
        codec.release()
        muxer.stop()
        muxer.release()
    }

    /** Drops what was written so far, for a video given up on. */
    private fun abandon() {
        runCatching { codec.release() }
        runCatching { muxer.release() }
    }

    /** An input buffer, the output drained while there is none free. */
    private fun input(): Int {
        while (true) {
            val i = codec.dequeueInputBuffer(10_000)
            if (i >= 0) return i
            drain(false)
        }
    }

    /** Writes out what the encoder has ready: to its end, when [end]. */
    private fun drain(end: Boolean) {
        while (true) {
            val i = codec.dequeueOutputBuffer(info, 10_000)
            when {
                i == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!end) return
                i == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                }
                i >= 0 -> {
                    val buf = codec.getOutputBuffer(i)!!
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && info.size > 0) {
                        buf.position(info.offset)
                        buf.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buf, info)
                    }
                    codec.releaseOutputBuffer(i, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    companion object {
        private val worker = Executors.newSingleThreadExecutor()
        private val main = Handler(Looper.getMainLooper())
        private var writer: VideoWriter? = null

        fun attach(channel: MethodChannel) {
            channel.setMethodCallHandler { call, result ->
                worker.execute {
                    try {
                        when (call.method) {
                            "start" -> {
                                // One left behind by a run that never finished.
                                writer?.abandon()
                                writer = VideoWriter(
                                    call.argument<String>("path")!!,
                                    call.argument<Int>("width")!!,
                                    call.argument<Int>("height")!!,
                                    call.argument<Int>("fps")!!,
                                    call.argument<Int>("bitrate")!!,
                                )
                            }
                            "frame" -> writer!!.frame(call.arguments as ByteArray)
                            "finish" -> writer!!.finish().also { writer = null }
                            else -> {
                                main.post { result.notImplemented() }
                                return@execute
                            }
                        }
                        main.post { result.success(null) }
                    } catch (e: Exception) {
                        writer?.abandon()
                        writer = null
                        main.post { result.error("video", e.message, null) }
                    }
                }
            }
        }
    }
}
