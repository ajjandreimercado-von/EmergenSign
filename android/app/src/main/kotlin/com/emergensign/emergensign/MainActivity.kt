package com.emergensign.emergensign

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity
 *
 * Registers two Flutter platform channels:
 *
 *  1. MethodChannel "com.emergensign/hand_landmarker"
 *     - "initialize": Creates HandLandmarkerHelper and CameraFrameProcessor
 *     - "processFrame": Receives a YUV frame from Dart and feeds it to MediaPipe
 *     - "close": Releases MediaPipe resources
 *
 *  2. EventChannel "com.emergensign/hand_landmarks_stream"
 *     - Streams landmark results back to Dart in real time.
 *     - Each event is either:
 *         • List<Map> — one entry per detected hand, each map has:
 *             "handIndex" (Int), "handedness" (String), "landmarks" (List<Double> of 63 values)
 *         • List<Double>([-1.0]) — sentinel: no hand detected this frame
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val METHOD_CHANNEL = "com.emergensign/hand_landmarker"
        private const val EVENT_CHANNEL  = "com.emergensign/hand_landmarks_stream"
    }

    private var helper: HandLandmarkerHelper? = null
    private var processor: CameraFrameProcessor? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── EventChannel ──────────────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    Log.d(TAG, "EventChannel: listener attached")
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "EventChannel: listener cancelled")
                    eventSink = null
                }
            })

        // ── MethodChannel ─────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "initialize" -> {
                        try {
                            helper?.close()
                            helper = HandLandmarkerHelper(
                                context = applicationContext,
                                eventSink = eventSink
                            )
                            processor = CameraFrameProcessor(helper!!)
                            Log.d(TAG, "HandLandmarker initialized via MethodChannel")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "initialize failed: ${e.message}", e)
                            result.error("INIT_ERROR", e.message, null)
                        }
                    }

                    "processFrame" -> {
                        val proc = processor
                        if (proc == null) {
                            result.error("NOT_INITIALIZED",
                                "Call 'initialize' before 'processFrame'", null)
                            return@setMethodCallHandler
                        }
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>

                            val yBytes  = args["yBytes"]  as ByteArray
                            val uBytes  = args["uBytes"]  as ByteArray
                            val vBytes  = args["vBytes"]  as ByteArray
                            val width   = args["width"]   as Int
                            val height  = args["height"]  as Int
                            val rowStrideY  = args["rowStrideY"]  as Int
                            val rowStrideUV = args["rowStrideUV"] as Int
                            val pixelStrideUV = args["pixelStrideUV"] as Int

                            // Process asynchronously so we don't block the platform thread.
                            Thread {
                                proc.processYUV420Frame(
                                    yBytes, uBytes, vBytes,
                                    width, height,
                                    rowStrideY, rowStrideUV, pixelStrideUV
                                )
                            }.start()

                            result.success(null)
                        } catch (e: Exception) {
                            Log.e(TAG, "processFrame failed: ${e.message}", e)
                            result.error("FRAME_ERROR", e.message, null)
                        }
                    }

                    "close" -> {
                        helper?.close()
                        helper = null
                        processor = null
                        Log.d(TAG, "HandLandmarker closed via MethodChannel")
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
