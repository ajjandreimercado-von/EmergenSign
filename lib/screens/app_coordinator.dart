import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import '../main.dart';
import '../models/log_entry.dart';
import 'main_translation_screen.dart';
import 'error_state_screen.dart';
import 'responder_log_screen.dart';

class AppCoordinator extends StatefulWidget {
  const AppCoordinator({Key? key}) : super(key: key);

  @override
  _AppCoordinatorState createState() => _AppCoordinatorState();
}

class _AppCoordinatorState extends State<AppCoordinator> {
  String _activeScreen = 'main'; // 'main', 'error', 'log'
  bool _isDetecting = true;
  List<LogEntry> _logEntries = [
    LogEntry(id: '1', time: '10:42 AM', english: 'I cannot breathe properly', tagalog: 'Hindi ako makahinga nang maayos', severity: 'high', words: 4),
    LogEntry(id: '2', time: '10:43 AM', english: 'My head hurts very badly', tagalog: 'Sobrang sakit ng ulo ko', severity: 'high', words: 5),
    LogEntry(id: '3', time: '10:45 AM', english: 'I feel like vomiting', tagalog: 'Parang susuka ako', severity: 'medium', words: 4),
    LogEntry(id: '4', time: '10:47 AM', english: 'The room is spinning around me', tagalog: 'Umiikot ang paligid ko', severity: 'medium', words: 6),
    LogEntry(id: '5', time: '10:49 AM', english: 'I have severe chest pain', tagalog: 'Mayroon akong matinding sakit sa dibdib', severity: 'high', words: 5),
  ];
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (cameras.isNotEmpty) {
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front, 
        orElse: () => cameras.first
      );
      _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
      try {
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Camera error: $e');
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }


  void _handleStopDetection() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDetecting = false;
    });
  }

  void _handleResumeDetection() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDetecting = true;
      _activeScreen = 'main';
    });
  }

  void _handleAddLogEntry(LogEntry entry) {
    setState(() {
      _logEntries.add(entry);
    });
  }

  Future<void> _handleExportLog() async {
    HapticFeedback.lightImpact();
    final logData = jsonEncode(_logEntries.map((e) => e.toJson()).toList());
    
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/fsl-emergency-log-${DateTime.now().toIso8601String().split('T')[0]}.json');
      await file.writeAsString(logData);
      
      await Share.shareXFiles(
        [XFile(file.path)], 
        text: 'Patient Symptom Log'
      );
    } catch (e) {
      debugPrint('Error exporting log: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;
    switch (_activeScreen) {
      case 'error':
        screen = ErrorStateScreen(
          onBack: _handleResumeDetection,
          cameraController: _cameraController,
        );
        break;
      case 'log':
        screen = ResponderLogScreen(
          onBack: () => setState(() => _activeScreen = 'main'),
          logEntries: _logEntries,
          onExportLog: _handleExportLog,
        );
        break;
      case 'main':
      default:
        screen = MainTranslationScreen(
          onNavigateToLog: () => setState(() => _activeScreen = 'log'),
          onShowError: () => setState(() => _activeScreen = 'error'),
          onStop: _handleStopDetection,
          onResume: _handleResumeDetection,
          isDetecting: _isDetecting,
          onAddLogEntry: _handleAddLogEntry,
          cameraController: _cameraController,
        );
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // slate-900
      body: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: screen,
        ),
      ),
    );
  }
}
