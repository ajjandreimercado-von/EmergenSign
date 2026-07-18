import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/landmark_result.dart';

/// HandLandmarkService
///
/// Dart-side bridge to the native Android MediaPipe HandLandmarker.
///
/// Usage:
///   1. Call [initialize] once after the CameraController is ready.
///   2. Pass each [CameraImage] from startImageStream to [processFrame].
///   3. Listen to [landmarkStream] for typed [LandmarkResult] events.
///   4. Call [dispose] when done (e.g. in widget dispose()).
class HandLandmarkService {
  static const _methodChannel =
      MethodChannel('com.emergensign/hand_landmarker');
  static const _eventChannel =
      EventChannel('com.emergensign/hand_landmarks_stream');

  Stream<LandmarkResult>? _landmarkStream;
  StreamSubscription<dynamic>? _rawSubscription;
  final _controller = StreamController<LandmarkResult>.broadcast();

  bool _initialized = false;
  bool _processingFrame = false;

  /// Typed stream of landmark results, emitted once per camera frame.
  Stream<LandmarkResult> get landmarkStream => _controller.stream;

  /// Initialize the native HandLandmarker and begin listening to the EventChannel.
  Future<void> initialize() async {
    if (_initialized) return;

    // Start listening to the native EventChannel first so the sink is ready
    // before we initialize the HandLandmarker on the native side.
    _rawSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_onRawEvent, onError: _onError);

    await _methodChannel.invokeMethod<void>('initialize');
    _initialized = true;
    debugPrint('[HandLandmarkService] Initialized');
  }

  /// Send a camera frame to native for MediaPipe processing.
  ///
  /// Call this from CameraController.startImageStream.
  /// Frames are skipped if the previous one hasn't finished to avoid backpressure.
  Future<void> processFrame(CameraImage image) async {
    if (!_initialized || _processingFrame) return;
    if (image.format.group != ImageFormatGroup.yuv420) {
      // Only YUV420 is supported on Android. CameraX always uses yuv420.
      return;
    }

    _processingFrame = true;
    try {
      final planes = image.planes;
      await _methodChannel.invokeMethod<void>('processFrame', {
        'yBytes': planes[0].bytes,
        'uBytes': planes[1].bytes,
        'vBytes': planes[2].bytes,
        'width': image.width,
        'height': image.height,
        'rowStrideY': planes[0].bytesPerRow,
        'rowStrideUV': planes[1].bytesPerRow,
        'pixelStrideUV': planes[1].bytesPerPixel ?? 1,
      });
    } catch (e) {
      debugPrint('[HandLandmarkService] processFrame error: $e');
    } finally {
      _processingFrame = false;
    }
  }

  void _onRawEvent(dynamic raw) {
    final result = LandmarkResult.fromRaw(raw);
    if (!_controller.isClosed) {
      _controller.add(result);
    }
  }

  void _onError(dynamic error) {
    debugPrint('[HandLandmarkService] EventChannel error: $error');
  }

  /// Release all native and Dart resources.
  Future<void> dispose() async {
    _initialized = false;
    await _rawSubscription?.cancel();
    await _controller.close();
    try {
      await _methodChannel.invokeMethod<void>('close');
    } catch (e) {
      debugPrint('[HandLandmarkService] close error: $e');
    }
    debugPrint('[HandLandmarkService] Disposed');
  }
}
