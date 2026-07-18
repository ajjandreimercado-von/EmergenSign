package com.emergensign.emergensign

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.plugin.common.EventChannel

/**
 * HandLandmarkerHelper
 *
 * Wraps MediaPipe's HandLandmarker Tasks Vision API in LIVE_STREAM mode.
 * Detects up to 2 hands per frame, applies wrist-relative normalization,
 * and emits results through a Flutter EventChannel sink.
 *
 * Output format per detected hand: List<Double> of 63 values (21 landmarks × [x, y, z]).
 * Coordinates are normalized relative to landmark[0] (wrist), making them
 * translation and scale invariant.
 *
 * "No hand" signal: a List<Double> containing a single value [-1.0].
 *
 * All processing is fully on-device — no network access is used or required.
 */
class HandLandmarkerHelper(
    private val context: Context,
    private val eventSink: EventChannel.EventSink?,
    private val minHandDetectionConfidence: Float = 0.5f,
    private val minHandPresenceConfidence: Float = 0.5f,
    private val minTrackingConfidence: Float = 0.5f,
    private val numHands: Int = 2
) {
    companion object {
        private const val TAG = "HandLandmarkerHelper"
        private const val MODEL_ASSET = "hand_landmarker.task"
        // Sentinel value indicating no hand was detected in this frame.
        private val NO_HAND_SIGNAL = listOf(-1.0)
    }

    private var handLandmarker: HandLandmarker? = null

    init {
        setupHandLandmarker()
    }

    private fun setupHandLandmarker() {
        val baseOptions = BaseOptions.builder()
            // Load model from the app's assets directory — fully offline.
            .setModelAssetPath(MODEL_ASSET)
            .build()

        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumHands(numHands)
            .setMinHandDetectionConfidence(minHandDetectionConfidence)
            .setMinHandPresenceConfidence(minHandPresenceConfidence)
            .setMinTrackingConfidence(minTrackingConfidence)
            .setResultListener { result, _ -> onResults(result) }
            .setErrorListener { error ->
                Log.e(TAG, "MediaPipe HandLandmarker error: ${error.message}", error)
            }
            .build()

        try {
            handLandmarker = HandLandmarker.createFromOptions(context, options)
            Log.d(TAG, "HandLandmarker initialized successfully (numHands=$numHands)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize HandLandmarker: ${e.message}", e)
        }
    }

    /**
     * Detect hand landmarks asynchronously from a Bitmap frame.
     * Results are delivered via the LIVE_STREAM callback (onResults).
     *
     * @param bitmap  ARGB_8888 bitmap of the camera frame.
     * @param timestampMs  Frame timestamp in milliseconds; must be monotonically increasing.
     */
    fun detectAsync(bitmap: Bitmap, timestampMs: Long) {
        val landmarker = handLandmarker ?: run {
            Log.w(TAG, "detectAsync called before HandLandmarker is ready")
            return
        }
        try {
            val mpImage = BitmapImageBuilder(bitmap).build()
            landmarker.detectAsync(mpImage, timestampMs)
        } catch (e: Exception) {
            Log.e(TAG, "detectAsync failed: ${e.message}", e)
        }
    }

    /**
     * Called by MediaPipe on the LIVE_STREAM result callback thread.
     * Normalizes landmarks (wrist-relative) and pushes results to the EventChannel sink.
     */
    private fun onResults(result: HandLandmarkerResult) {
        val handLandmarksList = result.landmarks()

        if (handLandmarksList.isEmpty()) {
            // No hand detected — signal the Dart side to reset the buffer.
            emitOnMainThread(NO_HAND_SIGNAL)
            Log.d(TAG, "No hand detected")
            return
        }

        // Emit one result map per detected hand.
        // Map keys: "handIndex" (0 or 1), "landmarks" (flat 63-value list), "handedness" (String)
        val handsData = mutableListOf<Map<String, Any>>()

        for ((index, landmarks) in handLandmarksList.withIndex()) {
            // Wrist is landmark[0]; normalize all points relative to it.
            val wristX = landmarks[0].x()
            val wristY = landmarks[0].y()
            val wristZ = landmarks[0].z()

            val flat = ArrayList<Double>(63)
            for (lm in landmarks) {
                flat.add((lm.x() - wristX).toDouble())
                flat.add((lm.y() - wristY).toDouble())
                flat.add((lm.z() - wristZ).toDouble())
            }

            val handedness = if (index < result.handedness().size) {
                result.handedness()[index].firstOrNull()?.categoryName() ?: "Unknown"
            } else "Unknown"

            handsData.add(
                mapOf(
                    "handIndex" to index,
                    "handedness" to handedness,
                    "landmarks" to flat
                )
            )

            Log.d(TAG, "Hand[$index]($handedness) wrist-relative[0..2]: " +
                    "${flat[0]}, ${flat[1]}, ${flat[2]}")
        }

        emitOnMainThread(handsData)
    }

    /**
     * EventChannel.EventSink.success() must be called on the platform (main) thread.
     */
    private fun emitOnMainThread(data: Any) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                eventSink?.success(data)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to emit to EventChannel: ${e.message}", e)
            }
        }
    }

    /** Release MediaPipe resources when the screen is disposed. */
    fun close() {
        handLandmarker?.close()
        handLandmarker = null
        Log.d(TAG, "HandLandmarker closed")
    }
}
