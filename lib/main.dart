import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/app_coordinator.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error in fetching the cameras: $e');
  }
  runApp(const EmergenSignApp());
}

class EmergenSignApp extends StatelessWidget {
  const EmergenSignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmergenSign',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        fontFamily: 'Inter', // Default web font look
      ),
      home: const AppCoordinator(),
    );
  }
}
