import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ErrorStateScreen extends StatelessWidget {
  final VoidCallback onBack;
  final CameraController? cameraController;

  const ErrorStateScreen({Key? key, required this.onBack, this.cameraController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                onPressed: onBack,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Resume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
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
            ],
          ),
        ),

        // Camera with Error Overlay
        Expanded(
          child: Container(
            color: const Color(0xFF0F172A),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cameraController != null && cameraController!.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: cameraController!.value.previewSize?.height ?? 1,
                      height: cameraController!.value.previewSize?.width ?? 1,
                      child: CameraPreview(cameraController!),
                    ),
                  ),
                Container(color: Colors.black.withOpacity(0.5)),

                // Faded Guide
                Center(
                  child: Opacity(
                    opacity: 0.2,
                    child: CustomPaint(
                      size: const Size(200, 300),
                      painter: GuidePainter(),
                    ),
                  ),
                ),

                // Error Card
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFFF9800)),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Poor Hand Visibility',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ensure your hands are clearly visible and well-lit for accurate phrase detection',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(child: Opacity(opacity: 0.3, child: Text('✋', style: TextStyle(fontSize: 24)))),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Too dark', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFDC2626))),
                                ],
                              ),
                              const SizedBox(width: 16),
                              const Text('→', style: TextStyle(fontSize: 20, color: Color(0xFFCBD5E1))),
                              const SizedBox(width: 16),
                              Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      border: Border.all(color: const Color(0xFF22C55E), width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(child: Text('✋', style: TextStyle(fontSize: 24))),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Well lit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF16A34A))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: onBack,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Paused', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
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
