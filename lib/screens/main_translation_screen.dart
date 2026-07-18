import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import '../models/landmark_result.dart';
import '../models/log_entry.dart';

class MainTranslationScreen extends StatefulWidget {
  final VoidCallback onNavigateToLog;
  final VoidCallback onShowError;
  final VoidCallback onStop;
  final VoidCallback onResume;
  final bool isDetecting;
  final Function(LogEntry) onAddLogEntry;
  final CameraController? cameraController;

  // ── New: landmark overlay props ───────────────────────────────────────────
  final LandmarkResult? latestLandmarkResult;
  final CameraLensDirection lensDirection;
  final VoidCallback onToggleCamera;
  final int bufferProgress; // 0–30 frames buffered

  const MainTranslationScreen({
    Key? key,
    required this.onNavigateToLog,
    required this.onShowError,
    required this.onStop,
    required this.onResume,
    required this.isDetecting,
    required this.onAddLogEntry,
    this.cameraController,
    this.latestLandmarkResult,
    this.lensDirection = CameraLensDirection.front,
    required this.onToggleCamera,
    this.bufferProgress = 0,
  }) : super(key: key);

  @override
  _MainTranslationScreenState createState() => _MainTranslationScreenState();
}

class _MainTranslationScreenState extends State<MainTranslationScreen>
    with SingleTickerProviderStateMixin {
  final _currentPhrase = {
    'english': 'I have severe chest pain',
    'tagalog': 'Mayroon akong matinding sakit sa dibdib',
    'confidence': 94,
    'words': ['I have', 'severe', 'chest pain'],
  };

  int _detectedWords = 3;
  bool _isPlayingAudio = false;
  Timer? _simulationTimer;
  late AnimationController _pulseController;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });

    _startSimulation();
  }

  @override
  void didUpdateWidget(MainTranslationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDetecting != oldWidget.isDetecting) {
      if (widget.isDetecting) {
        _startSimulation();
      } else {
        _simulationTimer?.cancel();
      }
    }
  }

  void _startSimulation() {
    _simulationTimer?.cancel();
    if (!widget.isDetecting) return;

    setState(() => _detectedWords = 0);

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          final wordsList = _currentPhrase['words'] as List<String>;
          if (_detectedWords < wordsList.length) _detectedWords++;
        });
      }
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    _simulationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePlayAudio() async {
    HapticFeedback.lightImpact();
    setState(() => _isPlayingAudio = true);
    await flutterTts.setLanguage("en-US");
    await flutterTts.speak(_currentPhrase['english'] as String);
  }

  void _handleStopAudio() async {
    HapticFeedback.lightImpact();
    await flutterTts.stop();
    setState(() => _isPlayingAudio = false);
  }

  void _handleStop() {
    _handleStopAudio();
    final now = DateTime.now();
    widget.onAddLogEntry(LogEntry(
      id: now.millisecondsSinceEpoch.toString(),
      time: DateFormat('h:mm a').format(now),
      english: _currentPhrase['english'] as String,
      tagalog: _currentPhrase['tagalog'] as String,
      severity: 'high',
      words: (_currentPhrase['words'] as List).length,
    ));
    widget.onStop();
  }

  @override
  Widget build(BuildContext context) {
    final wordsList = _currentPhrase['words'] as List<String>;
    final hasHand = widget.latestLandmarkResult?.handDetected ?? false;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16, right: 16, bottom: 12,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: widget.isDetecting ? _handleStop : widget.onResume,
                icon: Icon(widget.isDetecting ? Icons.close : Icons.play_arrow, size: 20),
                label: Text(
                  widget.isDetecting ? 'Stop' : 'Resume',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDetecting ? const Color(0xFFD32F2F) : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              Row(
                children: [
                  // ── Offline badge ──────────────────────────────────────
                  GestureDetector(
                    onTap: widget.onShowError,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('Offline',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF047857))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── Camera flip button ─────────────────────────────────
                  IconButton(
                    onPressed: widget.onToggleCamera,
                    tooltip: widget.lensDirection == CameraLensDirection.front
                        ? 'Switch to rear camera'
                        : 'Switch to front camera',
                    icon: const Icon(Icons.flip_camera_android, color: Color(0xFF334155), size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      hoverColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onNavigateToLog,
                    icon: const Icon(Icons.description, color: Color(0xFF334155), size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      hoverColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Camera + Overlay (flex 7) ──────────────────────────────────────
        Expanded(
          flex: 7,
          child: Container(
            color: const Color(0xFF0F172A),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                if (widget.cameraController != null &&
                    widget.cameraController!.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: widget.cameraController!.value.previewSize?.height ?? 1,
                      height: widget.cameraController!.value.previewSize?.width ?? 1,
                      child: CameraPreview(widget.cameraController!),
                    ),
                  ),

                // ── Hand skeleton overlay ──────────────────────────────────
                if (widget.latestLandmarkResult != null &&
                    widget.latestLandmarkResult!.handDetected)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: HandSkeletonPainter(
                          result: widget.latestLandmarkResult!,
                          isFrontCamera: widget.lensDirection == CameraLensDirection.front,
                        ),
                      );
                    },
                  ),

                // ── Guide outline (shown when no hand detected) ────────────
                if (!hasHand)
                  Center(
                    child: Opacity(
                      opacity: 0.3,
                      child: CustomPaint(
                        size: const Size(200, 300),
                        painter: GuidePainter(),
                      ),
                    ),
                  ),

                // ── Buffer progress bar ────────────────────────────────────
                if (widget.isDetecting)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: widget.bufferProgress / 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasHand ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),

                // ── Position instruction ───────────────────────────────────
                Positioned(
                  bottom: 28, left: 0, right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: hasHand ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Position hands in frame',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Detecting badge ────────────────────────────────────────
                if (widget.isDetecting)
                  Positioned(
                    top: 16, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          FadeTransition(
                            opacity: _pulseController,
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Detecting',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                // ── Hand count badge ───────────────────────────────────────
                if (hasHand)
                  Positioned(
                    top: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.latestLandmarkResult!.hands.length} hand${widget.latestLandmarkResult!.hands.length > 1 ? 's' : ''} detected',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ),

                // ── Phrase building overlay ────────────────────────────────
                if (widget.isDetecting && _detectedWords < wordsList.length)
                  Positioned(
                    top: 64, left: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Building phrase...',
                            style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: List.generate(wordsList.length, (i) {
                              final isDetected = i < _detectedWords;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDetected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isDetected ? null : Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Text(
                                  wordsList[i],
                                  style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500,
                                    color: isDetected ? Colors.white : Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text('$_detectedWords of ${wordsList.length} detected',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF34D399))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Translation output (flex 3) ────────────────────────────────────
        Expanded(
          flex: 3,
          child: Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).padding.bottom > 20
                  ? MediaQuery.of(context).padding.bottom
                  : 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFF1976D2), width: 2)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Translated',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF16A34A))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentPhrase['english'] as String,
                              style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A), height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentPhrase['tagalog'] as String,
                              style: const TextStyle(fontSize: 16, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: _isPlayingAudio ? _handleStopAudio : _handlePlayAudio,
                        icon: Icon(
                          _isPlayingAudio ? Icons.mic_off : Icons.mic,
                          color: Colors.white, size: 28,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: _isPlayingAudio
                              ? const Color(0xFF334155)
                              : const Color(0xFF1976D2),
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Confidence',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                            Text('${_currentPhrase['confidence']}%',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_currentPhrase['confidence'] as int) / 100,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HandSkeletonPainter
// ═══════════════════════════════════════════════════════════════════════════

/// Draws the MediaPipe hand skeleton over the live camera preview.
///
/// Landmarks are in normalized [0,1] coords relative to the image frame.
/// We map them to canvas pixel coordinates using the canvas Size.
///
/// For the front (selfie) camera, x is mirrored to match the mirrored preview.
class HandSkeletonPainter extends CustomPainter {
  final LandmarkResult result;
  final bool isFrontCamera;

  HandSkeletonPainter({required this.result, required this.isFrontCamera});

  // ── Paint styles ─────────────────────────────────────────────────────────

  static final _bonePaint = Paint()
    ..color = const Color(0xFF60A5FA)   // blue-400
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final _thumbBonePaint = Paint()
    ..color = const Color(0xFF34D399)   // emerald-400 for thumb
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final _jointPaint = Paint()
    ..color = const Color(0xFF93C5FD)   // blue-300
    ..style = PaintingStyle.fill;

  static final _fingertipPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  static final _wristPaint = Paint()
    ..color = const Color(0xFF4ADE80)   // green-400
    ..style = PaintingStyle.fill;

  // Fingertip landmark indices in MediaPipe's hand graph.
  static const _fingertips = {4, 8, 12, 16, 20};
  // Thumb bone connection indices (from kHandConnections).
  static const _thumbConnectionIndices = {0, 1, 2, 3};

  @override
  void paint(Canvas canvas, Size size) {
    for (final hand in result.hands) {
      _drawHand(canvas, size, hand);
    }
  }

  void _drawHand(Canvas canvas, Size size, HandLandmarks hand) {
    final lms = hand.landmarks;

    // The wrist (lm[0]) is at (0,0) after normalization.
    // We need to use raw screen coords, which means we need to un-normalize
    // back. Since normalization was wrist-relative, we use lm[0] raw coords.
    // However: MediaPipe's LIVE_STREAM callback gives us normalized [0,1] x,y
    // BEFORE wrist subtraction is done on our raw input. After normalization
    // our wrist (lm[0]) is always (0,0,0) — we cannot recover screen position.
    //
    // To correctly position the skeleton on screen we need the raw normalized
    // coords. The native side sends wrist-relative coords for the LSTM buffer,
    // but for the overlay we need absolute positions.
    //
    // ── Solution ────────────────────────────────────────────────────────────
    // The wrist-relative normalization makes wrist = (0,0). All other points
    // are relative offsets. For the painter we just use the x/y offsets
    // scaled to the canvas — the skeleton is correctly shaped but centered
    // at (0.5, 0.5) since wrist=origin maps to center. This gives a correct
    // skeleton shape overlay.
    //
    // For a perfectly positioned overlay (tracking actual hand position on screen),
    // see the TODO below to pass raw coords via a separate field.
    //
    // TODO (optional polish): modify HandLandmarkerHelper.kt to also emit the
    // raw (un-normalized) landmark[0] wrist position so we can anchor the
    // skeleton at the correct screen position.

    // Map wrist-relative coords to canvas, centering the wrist at screen center.
    Offset toOffset(List<double> lm) {
      // lm[0] (wrist) = 0.0 → map to canvas center (0.5 * w, 0.5 * h).
      // Scale factor chosen so ±0.5 normalized units span ~40% of the canvas.
      const scale = 0.8;
      double x = 0.5 + lm[0] * scale;
      double y = 0.5 + lm[1] * scale;
      // Mirror x for front camera.
      if (isFrontCamera) x = 1.0 - x;
      return Offset(x * size.width, y * size.height);
    }

    final points = lms.map(toOffset).toList();

    // Draw bones (connections between joints).
    for (int ci = 0; ci < kHandConnections.length; ci++) {
      final conn = kHandConnections[ci];
      final a = points[conn[0]];
      final b = points[conn[1]];
      final isThumb = _thumbConnectionIndices.contains(ci);
      canvas.drawLine(a, b, isThumb ? _thumbBonePaint : _bonePaint);
    }

    // Draw joint dots.
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if (i == 0) {
        // Wrist — larger green dot.
        canvas.drawCircle(pt, 6, _wristPaint);
      } else if (_fingertips.contains(i)) {
        // Fingertips — white dots.
        canvas.drawCircle(pt, 5, _fingertipPaint);
        // Blue ring around fingertip.
        canvas.drawCircle(pt, 5, Paint()
          ..color = const Color(0xFF3B82F6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        // Regular joint — blue dot.
        canvas.drawCircle(pt, 3.5, _jointPaint);
      }
    }

    // Draw handedness label near wrist.
    final wristPt = points[0];
    final textPainter = TextPainter(
      text: TextSpan(
        text: hand.handedness,
        style: TextStyle(
          color: hand.handedness == 'Left'
              ? const Color(0xFF34D399)
              : const Color(0xFFFBBF24),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(wristPt.dx + 8, wristPt.dy - 8));
  }

  @override
  bool shouldRepaint(HandSkeletonPainter oldDelegate) =>
      oldDelegate.result != result;
}

// ═══════════════════════════════════════════════════════════════════════════
// GuidePainter  (unchanged — shown when no hand is detected)
// ═══════════════════════════════════════════════════════════════════════════

class GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(const Offset(100, 40), 25, paint);

    final path = Path()
      ..moveTo(75, 65) ..lineTo(75, 90)
      ..quadraticBezierTo(75, 110, 85, 120) ..lineTo(85, 180)
      ..moveTo(125, 65) ..lineTo(125, 90)
      ..quadraticBezierTo(125, 110, 115, 120) ..lineTo(115, 180)
      ..moveTo(75, 65) ..lineTo(125, 65);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
