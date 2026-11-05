// lib/features/voice/domain/controllers/voice_session_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

enum VoiceSessionStatus {
  idle,
  userListening,
  processing,
  agentSpeaking,
  completed,
  error
}

class VoiceSessionController extends ChangeNotifier {
  VoiceSessionStatus _status = VoiceSessionStatus.idle;
  Duration _remaining = const Duration(seconds: 30);
  Timer? _countdownTimer;
  final Stopwatch _stopwatch = Stopwatch();

  VoiceSessionStatus get status => _status;
  Duration get remaining => _remaining;
  bool get isListening => _status == VoiceSessionStatus.userListening;

  void startCall() {
    _startListeningTurn();
  }

  void _startListeningTurn() {
    _status = VoiceSessionStatus.userListening;
    _remaining = const Duration(seconds: 30);
    _stopwatch.reset();
    _stopwatch.start();
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final elapsed = _stopwatch.elapsed;
      _remaining = const Duration(seconds: 30) - elapsed;

      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        timer.cancel();
        _stopwatch.stop();
        completeUserSpeechTurn();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> completeUserSpeechTurn() async {
    _countdownTimer?.cancel();
    _stopwatch.stop();
    _status = VoiceSessionStatus.processing;
    notifyListeners();
  }

  void playAgentResponse(String ttsAudioPath, {required bool isDisambiguation}) {
    _status = VoiceSessionStatus.agentSpeaking;
    notifyListeners();

    // When TTS playback completes:
    if (isDisambiguation) {
      _startListeningTurn(); // Auto-reopen mic without user interaction
    } else {
      _status = VoiceSessionStatus.completed;
      notifyListeners();
    }
  }

  void endCall() {
    _countdownTimer?.cancel();
    _stopwatch.stop();
    _status = VoiceSessionStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}

