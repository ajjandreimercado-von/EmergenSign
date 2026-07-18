/// Typed model representing one frame's hand landmark detection result.
///
/// [handDetected] — false when MediaPipe found no hands this frame.
/// [hands]        — list of per-hand landmark data (1 or 2 hands).
///
/// When [handDetected] is false, [hands] is empty.
/// When [handDetected] is true, [hands] contains 1–2 [HandLandmarks] objects.
class LandmarkResult {
  final bool handDetected;
  final List<HandLandmarks> hands;

  const LandmarkResult({
    required this.handDetected,
    required this.hands,
  });

  /// Sentinel: no hand detected.
  factory LandmarkResult.noHand() =>
      const LandmarkResult(handDetected: false, hands: []);

  /// Parse raw data from the EventChannel.
  ///
  /// Native sends either:
  ///   • [List] with single element -1.0  → no hand
  ///   • [List<Map>]                      → one entry per detected hand
  factory LandmarkResult.fromRaw(dynamic raw) {
    if (raw is List && raw.length == 1 && raw.first is double && raw.first == -1.0) {
      return LandmarkResult.noHand();
    }

    if (raw is List) {
      final hands = <HandLandmarks>[];
      for (final entry in raw) {
        if (entry is Map) {
          hands.add(HandLandmarks.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
      return LandmarkResult(handDetected: hands.isNotEmpty, hands: hands);
    }

    return LandmarkResult.noHand();
  }
}

/// Landmark data for a single detected hand.
///
/// [handIndex]   — 0 for first detected hand, 1 for second.
/// [handedness]  — "Left" or "Right" as reported by MediaPipe.
/// [landmarks]   — 21 landmarks, each [x, y, z], wrist-relative normalised.
///                 Indices follow MediaPipe's hand graph (see HAND_CONNECTIONS).
/// [flat63]      — flat 63-value array for the LSTM model input.
class HandLandmarks {
  final int handIndex;
  final String handedness;

  /// 21 landmarks as [x, y, z] sublists (wrist-relative, normalized).
  final List<List<double>> landmarks;

  HandLandmarks({
    required this.handIndex,
    required this.handedness,
    required this.landmarks,
  });

  factory HandLandmarks.fromMap(Map<String, dynamic> map) {
    final rawFlat = List<double>.from(map['landmarks'] as List);
    final lms = <List<double>>[];
    for (int i = 0; i < rawFlat.length; i += 3) {
      lms.add([rawFlat[i], rawFlat[i + 1], rawFlat[i + 2]]);
    }
    return HandLandmarks(
      handIndex: map['handIndex'] as int,
      handedness: map['handedness'] as String,
      landmarks: lms,
    );
  }

  /// Flat 63-value list ready for LSTM input: [x0,y0,z0, x1,y1,z1, ..., x20,y20,z20]
  List<double> get flat63 => landmarks.expand((lm) => lm).toList();
}

/// MediaPipe hand connection graph — pairs of landmark indices forming bone segments.
/// Used by [HandSkeletonPainter] to draw the skeleton overlay.
const List<List<int>> kHandConnections = [
  // Thumb
  [0, 1], [1, 2], [2, 3], [3, 4],
  // Index
  [0, 5], [5, 6], [6, 7], [7, 8],
  // Middle
  [0, 9], [9, 10], [10, 11], [11, 12],
  // Ring
  [0, 13], [13, 14], [14, 15], [15, 16],
  // Pinky
  [0, 17], [17, 18], [18, 19], [19, 20],
  // Palm cross connections
  [5, 9], [9, 13], [13, 17],
];
