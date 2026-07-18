package com.emergensign.emergensign

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.util.Log
import java.io.ByteArrayOutputStream

/**
 * CameraFrameProcessor
 *
 * Converts raw camera frame bytes (YUV420 / NV21) received from Flutter's
 * camera plugin into an ARGB_8888 Bitmap, then feeds it into HandLandmarkerHelper.
 *
 * Flutter's camera plugin delivers frames via CameraImage which encodes pixels as
 * YUV420 (Android's most common format). We convert via YuvImage → JPEG → Bitmap
 * because Android does not expose a direct YUV420 → Bitmap API at API 26.
 *
 * Note: The JPEG step adds a small amount of compression artifact (quality=90)
 * but the landmark accuracy impact is negligible for this use-case.
 */
class CameraFrameProcessor(private val helper: HandLandmarkerHelper) {

    companion object {
        private const val TAG = "CameraFrameProcessor"
        private const val JPEG_QUALITY = 90
    }

    private var frameTimestamp = 0L

    /**
     * Process a camera frame received from Flutter.
     *
     * @param yBytes  Y plane byte array (luminance)
     * @param uBytes  U plane byte array (Cb chrominance)
     * @param vBytes  V plane byte array (Cr chrominance)
     * @param width   Frame width in pixels
     * @param height  Frame height in pixels
     * @param rowStrideY  Row stride of Y plane
     * @param rowStrideUV  Row stride of U/V planes
     * @param pixelStrideUV  Pixel stride of U/V planes (interleave factor)
     */
    fun processYUV420Frame(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        rowStrideY: Int,
        rowStrideUV: Int,
        pixelStrideUV: Int
    ) {
        try {
            val bitmap = yuv420ToBitmap(yBytes, uBytes, vBytes, width, height,
                rowStrideY, rowStrideUV, pixelStrideUV)

            // Timestamp must be monotonically increasing for LIVE_STREAM mode.
            frameTimestamp = System.currentTimeMillis()
            helper.detectAsync(bitmap, frameTimestamp)

            bitmap.recycle()
        } catch (e: Exception) {
            Log.e(TAG, "Frame processing error: ${e.message}", e)
        }
    }

    /**
     * Converts YUV420 planes to ARGB_8888 Bitmap via NV21 → YuvImage → JPEG → Bitmap.
     *
     * This handles both "packed" (pixelStride=1) and "semi-planar" (pixelStride=2) UV formats.
     */
    private fun yuv420ToBitmap(
        yBytes: ByteArray, uBytes: ByteArray, vBytes: ByteArray,
        width: Int, height: Int,
        rowStrideY: Int, rowStrideUV: Int, pixelStrideUV: Int
    ): Bitmap {
        // Build NV21 byte array: Y plane followed by interleaved V/U (NV21 format).
        val nv21Size = width * height + (width / 2) * (height / 2) * 2
        val nv21 = ByteArray(nv21Size)

        // Copy Y plane, handling row stride padding.
        if (rowStrideY == width) {
            System.arraycopy(yBytes, 0, nv21, 0, width * height)
        } else {
            var yOffset = 0
            for (row in 0 until height) {
                System.arraycopy(yBytes, row * rowStrideY, nv21, yOffset, width)
                yOffset += width
            }
        }

        // Interleave V and U into NV21 UV block (V first, then U).
        var uvOffset = width * height
        val uvHeight = height / 2
        val uvWidth = width / 2

        if (pixelStrideUV == 1) {
            // Fully planar I420: U and V planes are separate and packed.
            for (row in 0 until uvHeight) {
                for (col in 0 until uvWidth) {
                    nv21[uvOffset++] = vBytes[row * rowStrideUV / pixelStrideUV + col]
                    nv21[uvOffset++] = uBytes[row * rowStrideUV / pixelStrideUV + col]
                }
            }
        } else {
            // Semi-planar NV12/NV21: pixels are interleaved, pixelStride = 2.
            for (row in 0 until uvHeight) {
                for (col in 0 until uvWidth) {
                    val srcIndex = row * rowStrideUV + col * pixelStrideUV
                    nv21[uvOffset++] = vBytes[srcIndex]
                    nv21[uvOffset++] = uBytes[srcIndex]
                }
            }
        }

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), JPEG_QUALITY, out)
        val jpegBytes = out.toByteArray()

        return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
            ?: throw IllegalStateException("BitmapFactory failed to decode JPEG frame")
    }
}
