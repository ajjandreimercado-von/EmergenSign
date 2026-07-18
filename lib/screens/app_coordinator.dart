import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../main.dart';
import '../models/landmark_result.dart';
import '../models/log_entry.dart';
import '../services/hand_landmark_service.dart';
import '../services/landmark_buffer.dart';
import 'error_state_screen.dart';
import 'main_translation_screen.dart';
import 'responder_log_screen.dart';

class AppCoordinator extends StatefulWidget {
  const AppCoordinator({Key? key}) : super(key: key);

  @override
  _AppCoordinatorState createState() => _AppCoordinatorState();
}

class _AppCoordinatorState extends State<AppCoordinator> {
  String _activeScreen = 'main';
  bool _isDetecting = true;
  List<LogEntry> _logEntries = [
    LogEntry(id: '1', time: '10:42 AM', english: 'I cannot breathe properly', tagalog: 'Hindi ako makahinga nang maayos', severity: 'high', words: 4),
    LogEntry(id: '2', time: '10:43 AM', english: 'My head hurts very badly', tagalog: 'Sobrang sakit ng ulo ko', severity: 'high', words: 5),
    LogEntry(id: '3', time: '10:45 AM', english: 'I feel like vomiting', tagalog: 'Parang susuka ako', severity: 'medium', words: 4),
    LogEntry(id: '4', time: '10:47 AM', english: 'The room is spinning around me', tagalog: 'Umiikot ang paligid ko', severity: 'medium', words: 6),
    LogEntry(id: '5', time: '10:49 AM', english: 'I have severe chest pain', tagalog: 'Mayroon akong matinding sakit sa dibdib', severity: 'high', words: 5),
  ];

  // ── Camera ───────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitializing = false;

  // ── MediaPipe / Landmarks ─────────────────────────────────────────────────
  final _landmarkService = HandLandmarkService();
  final _landmarkBuffer  = LandmarkBuffer(frameCount: 30);
  StreamSubscription<LandmarkResult>? _landmarkSubscription;
  LandmarkResult? _latestLandmarkResult;

  @override
  void initState() {
    super.initState();
    _initCamera(_lensDirection);
  }

  // ── Camera initialisation ─────────────────────────────────────────────────

  Future<void> _initCamera(CameraLensDirection direction) async {
    if (_cameraInitializing) return;
    _cameraInitializing = true;

    // Stop any existing image stream + landmark service before switching.
    await _tearDownCamera();

    if (cameras.isEmpty) {
      _cameraInitializing = false;
      return;
    }

    final selected = cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      _cameraController = controller;

      // Boot MediaPipe and start streaming frames.
      await _landmarkService.initialize();
      _landmarkSubscription = _landmarkService.landmarkStream.listen(_onLandmarks);

      await controller.startImageStream((CameraImage image) {
        // Only stream when detecting; drop frames otherwise.
        if (_isDetecting) {
          _landmarkService.processFrame(image);
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[AppCoordinator] Camera init error: $e');
    } finally {
      _cameraInitializing = false;
    }
  }

  Future<void> _tearDownCamera() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _landmarkSubscription?.cancel();
    _landmarkSubscription = null;
    await _cameraController?.dispose();
    _cameraController = null;
    await _landmarkService.dispose();
  }

  /// Called on every MediaPipe result (once per camera frame).
  void _onLandmarks(LandmarkResult result) {
    if (!mounted) return;

    final bufferReady = _landmarkBuffer.addFrame(result);

    if (bufferReady) {
      // TODO: LSTM INFERENCE — retrieve _landmarkBuffer.sequence (30 × 126)
      // and pass it to your TFLite model when it's trained.
      // final sequence = _landmarkBuffer.sequence;
      // _landmarkBuffer.clear(); // clear after taking sequence
      debugPrint('[AppCoordinator] 30-frame buffer ready — LSTM stub');
    }

    setState(() {
      _latestLandmarkResult = result;
    });
  }

  // ── Camera toggle (front ↔ rear) ──────────────────────────────────────────

  void _handleToggleCamera() {
    HapticFeedback.lightImpact();
    final newDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    _lensDirection = newDirection;
    _initCamera(newDirection);
  }

  // ── Detection controls ────────────────────────────────────────────────────

  void _handleStopDetection() {
    HapticFeedback.lightImpact();
    setState(() => _isDetecting = false);
    _landmarkBuffer.clear();
  }

  void _handleResumeDetection() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDetecting = true;
      _activeScreen = 'main';
    });
  }

  void _handleAddLogEntry(LogEntry entry) {
    setState(() => _logEntries.add(entry));
  }

  Future<void> _handleExportLog() async {
    HapticFeedback.lightImpact();
    final logData = jsonEncode(_logEntries.map((e) => e.toJson()).toList());
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/fsl-emergency-log-${DateTime.now().toIso8601String().split('T')[0]}.json');
      await file.writeAsString(logData);
      await Share.shareXFiles([XFile(file.path)], text: 'Patient Symptom Log');
    } catch (e) {
      debugPrint('Error exporting log: $e');
    }
  }

  @override
  void dispose() {
    _tearDownCamera();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          latestLandmarkResult: _latestLandmarkResult,
          lensDirection: _lensDirection,
          onToggleCamera: _handleToggleCamera,
          bufferProgress: _landmarkBuffer.bufferedFrames,
        );
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
