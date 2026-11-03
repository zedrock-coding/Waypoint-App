// lib/features/voice/data/sherpa_tts_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/services/tts_service.dart';

class SherpaTtsService implements ITextToSpeechService {
  bool _isInitialized = false;
  bool _isPlaying = false;

  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;

  @override
  Future<void> initialize() async {
    // Sherpa-ONNX model initialization boundary
    _isInitialized = true;
    debugPrint('SherpaTtsService initialized');
  }

  @override
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    _isPlaying = true;
    debugPrint('SherpaTtsService speaking: $text');
    // Simulated synthetic playback duration based on word count
    final wordCount = text.split(' ').length;
    final ms = (wordCount * 250).clamp(500, 5000);
    await Future.delayed(Duration(milliseconds: ms));
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
  }

  @override
  void dispose() {
    _isPlaying = false;
    _isInitialized = false;
  }
}

