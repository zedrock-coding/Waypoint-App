// lib/features/voice/domain/services/tts_service.dart

import 'dart:async';

abstract class ITextToSpeechService {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  void dispose();
}

class MockTtsService implements ITextToSpeechService {
  bool isInitialized = false;
  bool isSpeaking = false;
  String? lastSpokenText;
  Completer<void>? _speakCompleter;
  final bool autoComplete;

  MockTtsService({this.autoComplete = true});

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> speak(String text) async {
    lastSpokenText = text;
    isSpeaking = true;
    if (autoComplete) {
      isSpeaking = false;
      return;
    }
    _speakCompleter = Completer<void>();
    await _speakCompleter!.future;
    isSpeaking = false;
  }

  void completeSpeaking() {
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
    isSpeaking = false;
  }

  @override
  Future<void> stop() async {
    completeSpeaking();
    isSpeaking = false;
  }

  @override
  void dispose() {
    completeSpeaking();
  }
}
