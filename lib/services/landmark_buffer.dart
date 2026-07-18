import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/landmark_result.dart';

/// LandmarkBuffer
///
/// Rolling 30-frame window of hand landmark vectors.
/// Designed for a 2-hand FSL LSTM model that expects input shape (30, 126):
///   - 30 frames × (63 values/hand × 2 hands) = 126 features per frame.
///
/// ── Rules ─────────────────────────────────────────────────────────────────
///   • Valid frame  : at least one hand detected → append to queue.
///   • Invalid frame: no hands detected          → RESET buffer (do not fill
///                                                  with zeros; a broken
///                                                  sequence is worthless).
///   • Full buffer  : when queue.length == frameCount → [isReady] = true,
///                    expose [sequence] for LSTM inference.
///                    The buffer is then cleared so the next sequence starts
///                    fresh (non-overlapping windows). Change this to a
///                    sliding window if your model was trained that way.
///
/// ── Feature vector per frame ──────────────────────────────────────────────
///   Hand 0 flat63  ++ Hand 1 flat63  →  126 doubles.
///   If only one hand is visible, the second 63 values are all 0.0.
///
/// TODO: LSTM INFERENCE
///   When [isReady] is true, retrieve [sequence] (List<List<double>>, shape 30×126)
///   and pass it to your LSTM model (e.g. via TFLite) for sign classification.
///   Example integration point:
///
///     if (buffer.isReady) {
///       final input = buffer.sequence;   // shape: 30 × 126
///       buffer.clear();                  // reset for next sequence
///       // TODO: pass `input` to your TFLite inference engine here
///     }
///
class LandmarkBuffer {
  final int frameCount;

  LandmarkBuffer({this.frameCount = 30});

  final Queue<List<double>> _queue = Queue();

  /// True when [frameCount] consecutive valid frames have been buffered.
  bool get isReady => _queue.length >= frameCount;

  /// Current number of buffered frames.
  int get bufferedFrames => _queue.length;

  /// The accumulated 30-frame sequence, shape [frameCount × 126].
  /// Only valid when [isReady] is true.
  List<List<double>> get sequence => _queue.toList();

  /// Add one frame's landmarks to the buffer.
  ///
  /// [result] — the [LandmarkResult] from [HandLandmarkService.landmarkStream].
  ///
  /// Returns true if the buffer became ready after this frame.
  bool addFrame(LandmarkResult result) {
    if (!result.handDetected) {
      // Broken sequence — discard everything accumulated so far.
      if (_queue.isNotEmpty) {
        debugPrint('[LandmarkBuffer] No hand — resetting (had ${_queue.length} frames)');
      }
      _queue.clear();
      return false;
    }

    // Build a 126-value feature vector (hand0 flat63 ++ hand1 flat63).
    final vec = List<double>.filled(126, 0.0);

    for (final hand in result.hands) {
      if (hand.handIndex == 0) {
        final f = hand.flat63;
        for (int i = 0; i < f.length; i++) vec[i] = f[i];
      } else if (hand.handIndex == 1) {
        final f = hand.flat63;
        for (int i = 0; i < f.length; i++) vec[63 + i] = f[i];
      }
    }

    _queue.add(vec);

    // Keep at most [frameCount] frames (sliding window behaviour).
    while (_queue.length > frameCount) {
      _queue.removeFirst();
    }

    if (isReady) {
      debugPrint('[LandmarkBuffer] Buffer full — 30 frames ready for inference');
    }

    return isReady;
  }

  /// Manually reset the buffer (e.g. after taking a sequence for inference).
  void clear() {
    _queue.clear();
    debugPrint('[LandmarkBuffer] Buffer cleared');
  }
}
