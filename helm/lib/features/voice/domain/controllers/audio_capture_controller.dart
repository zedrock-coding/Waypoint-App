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
  Duration _simulatedOffset = Duration.zero;

  VoidCallback? onLimitReached;
  VoidCallback? onAutoSubmit;
  Future<void> Function()? onStopRecorder;

  AudioCaptureController({
    this.maxDuration = const Duration(seconds: 30),
    this.onLimitReached,
    this.onAutoSubmit,
    this.onStopRecorder,
  }) : _state = RecordingState.initial();

  AudioCaptureStatus get status => _status;
  RecordingState get state => _state;
  Stream<RecordingState> get stream => _stateController.stream;

  Stopwatch get stopwatch => _stopwatch;
  Timer? get ticker => _ticker;
  bool get isTickerActive => _ticker?.isActive ?? false;
  bool get isRecording => _state.isRecording;
  bool get isLimitReached => _state.isLimitReached;

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

  void startRecording({
    VoidCallback? onLimitReached,
    VoidCallback? onAutoSubmit,
  }) {
    if (onLimitReached != null) this.onLimitReached = onLimitReached;
    if (onAutoSubmit != null) this.onAutoSubmit = onAutoSubmit;

    _status = AudioCaptureStatus.recording;
    _simulatedOffset = Duration.zero;
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

  void startMockRecording() => startRecording();
  void start({
    VoidCallback? onLimitReached,
    VoidCallback? onAutoSubmit,
  }) =>
      startRecording(
        onLimitReached: onLimitReached,
        onAutoSubmit: onAutoSubmit,
      );

  void fastForwardTimer(Duration delta) {
    if (!_state.isRecording) return;
    _simulatedOffset += delta;
    _applyElapsed(_stopwatch.elapsed + _simulatedOffset);
  }

  void fastForward(Duration delta) => fastForwardTimer(delta);

  void _onTick() {
    if (!_state.isRecording) return;
    final currentElapsed = _stopwatch.elapsed + _simulatedOffset;
    _applyElapsed(currentElapsed);
  }

  void _applyElapsed(Duration elapsed) {
    if (elapsed >= maxDuration ||
        _stopwatch.elapsedMilliseconds >= maxDuration.inMilliseconds) {
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

      onStopRecorder?.call();
      onLimitReached?.call();
      onAutoSubmit?.call();
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
    _stopwatch.reset();
    _simulatedOffset = Duration.zero;
    _ticker?.cancel();
    _ticker = null;
    _status = AudioCaptureStatus.idle;

    _state = _state.copyWith(
      isRecording: false,
      elapsed: Duration.zero,
      remaining: maxDuration,
    );
    _notify();
  }

  void stopRecording() => stop();

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    _stopwatch.reset();
    _stateController.close();
    super.dispose();
  }
}
