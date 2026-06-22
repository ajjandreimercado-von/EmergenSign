import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import '../models/log_entry.dart';

class MainTranslationScreen extends StatefulWidget {
  final VoidCallback onNavigateToLog;
  final VoidCallback onShowError;
  final VoidCallback onStop;
  final bool isDetecting;
  final Function(LogEntry) onAddLogEntry;
  final CameraController? cameraController;

  const MainTranslationScreen({
    Key? key,
    required this.onNavigateToLog,
    required this.onShowError,
    required this.onStop,
    required this.isDetecting,
    required this.onAddLogEntry,
    this.cameraController,
  }) : super(key: key);

  @override
  _MainTranslationScreenState createState() => _MainTranslationScreenState();
}

class _MainTranslationScreenState extends State<MainTranslationScreen> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
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
    
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          final wordsList = _currentPhrase['words'] as List<String>;
          if (_detectedWords < wordsList.length) {
            _detectedWords++;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePlayAudio() {
    HapticFeedback.lightImpact();
    setState(() => _isPlayingAudio = true);
    
    // Simulate TTS
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  void _handleStopAudio() {
    HapticFeedback.lightImpact();
    setState(() => _isPlayingAudio = false);
  }

  void _handleStop() {
    _handleStopAudio();
    
    final now = DateTime.now();
    final timeString = DateFormat('h:mm a').format(now);
    
    widget.onAddLogEntry(LogEntry(
      id: now.millisecondsSinceEpoch.toString(),
      time: timeString,
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
    
    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _handleStop,
                icon: const Icon(Icons.close, size: 20),
                label: const Text('Stop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF047857))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
        
        // Camera View (flex: 7)
        Expanded(
          flex: 7,
          child: Container(
            color: const Color(0xFF0F172A),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.cameraController != null && widget.cameraController!.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: widget.cameraController!.value.previewSize?.height ?? 1,
                      height: widget.cameraController!.value.previewSize?.width ?? 1,
                      child: CameraPreview(widget.cameraController!),
                    ),
                  ),
                // Guide Outline
                Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: CustomPaint(
                      size: const Size(200, 300),
                      painter: GuidePainter(),
                    ),
                  ),
                ),
                
                // Position Instruction
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
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
                
                // Status Badge
                if (widget.isDetecting)
                  Positioned(
                    top: 16,
                    left: 16,
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
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Detecting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  
                // Active Phrase Building
                if (widget.isDetecting && _detectedWords < wordsList.length)
                  Positioned(
                    top: 64,
                    left: 16,
                    right: 16,
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
                          const Text('Building phrase...', style: TextStyle(fontSize: 12, color: Color(0xFF93C5FD))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: List.generate(wordsList.length, (i) {
                              final isDetected = i < _detectedWords;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDetected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isDetected ? null : Border.all(color: Colors.white.withOpacity(0.2), style: BorderStyle.solid),
                                ),
                                child: Text(
                                  wordsList[i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDetected ? Colors.white : Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text('$_detectedWords of ${wordsList.length} detected', style: const TextStyle(fontSize: 12, color: Color(0xFF34D399))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Translation Output (flex: 3)
        Expanded(
          flex: 3,
          child: Container(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom > 20 ? MediaQuery.of(context).padding.bottom : 20),
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
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Translated', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF16A34A))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentPhrase['english'] as String,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.2),
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
                      icon: Icon(_isPlayingAudio ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: _isPlayingAudio ? const Color(0xFF334155) : const Color(0xFF1976D2),
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
                          const Text('Confidence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                          Text('${_currentPhrase['confidence']}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
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

class GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // Simplistic outline representation
    canvas.drawCircle(const Offset(100, 40), 25, paint);
    
    final path = Path()
      ..moveTo(75, 65)
      ..lineTo(75, 90)
      ..quadraticBezierTo(75, 110, 85, 120)
      ..lineTo(85, 180)
      ..moveTo(125, 65)
      ..lineTo(125, 90)
      ..quadraticBezierTo(125, 110, 115, 120)
      ..lineTo(115, 180)
      ..moveTo(75, 65)
      ..lineTo(125, 65);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
