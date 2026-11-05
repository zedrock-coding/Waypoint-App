// lib/features/voice/domain/controllers/audio_capture_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/recording_state.dart';

enum AudioCaptureStatus {
  idle,
  initializing,
  recording,
  paused,
  processing,
  error,
}

class AudioCaptureController extends ChangeNotifier {
  final Duration maxDuration;
  AudioCaptureStatus _status = AudioCaptureStatus.idle;
  RecordingState _state;
  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _amplitudeRingBuffer = List.filled(32, 0.0);
  int _ringBufferIndex = 0;
  final StreamController<RecordingState> _stateController =
      StreamController<RecordingState>.broadcast();

  Stream<RecordingState> get stream => _stateController.stream;

  AudioCaptureController({
    this.maxDuration = const Duration(seconds: 30),
  }) : _state = RecordingState.initial();

  AudioCaptureStatus get status => _status;
  RecordingState get state => _state;

  double normalizeDb(double dbFS) {
    final clamped = dbFS.clamp(-60.0, 0.0);
    return (clamped + 60.0) / 60.0;
  }

  void _notify() {
    notifyListeners();
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void updateAmplitude(double dbFS) {
    final normalized = normalizeDb(dbFS);
    _amplitudeRingBuffer[_ringBufferIndex] = normalized;
    _ringBufferIndex = (_ringBufferIndex + 1) % _amplitudeRingBuffer.length;

    _state = _state.copyWith(
      normalizedAmplitude: normalized,
      amplitudeHistory: List.unmodifiable(_amplitudeRingBuffer),
    );
    _notify();
  }

  void startMockRecording() {
    _status = AudioCaptureStatus.recording;
    _stopwatch.reset();
    _stopwatch.start();

    _state = _state.copyWith(
      isRecording: true,
      isLimitReached: false,
      elapsed: Duration.zero,
      remaining: maxDuration,
    );
    _notify();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _onTick();
    });
  }

  void fastForwardTimer(Duration delta) {
    if (!_state.isRecording) return;
    final newElapsed = _state.elapsed + delta;
    _applyElapsed(newElapsed);
  }

  void _onTick() {
    if (!_state.isRecording) return;
    _applyElapsed(_stopwatch.elapsed);
  }

  void _applyElapsed(Duration elapsed) {
    if (elapsed >= maxDuration) {
      _stopwatch.stop();
      _ticker?.cancel();
      _ticker = null;
      _status = AudioCaptureStatus.processing;

      _state = _state.copyWith(
        elapsed: maxDuration,
        remaining: Duration.zero,
        isRecording: false,
        isLimitReached: true,
      );
      _notify();
    } else {
      _state = _state.copyWith(
        elapsed: elapsed,
        remaining: maxDuration - elapsed,
      );
      _notify();
    }
  }

  void stop() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    _status = AudioCaptureStatus.idle;

    _state = _state.copyWith(
      isRecording: false,
    );
    _notify();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    _stateController.close();
    super.dispose();
  }
}

