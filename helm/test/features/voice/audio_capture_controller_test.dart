// test/features/voice/audio_capture_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/voice/domain/controllers/audio_capture_controller.dart';

void main() {
  group('AudioCaptureController Unit Tests', () {
    late AudioCaptureController controller;

    setUp(() {
      controller = AudioCaptureController(maxDuration: const Duration(seconds: 30));
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial state is idle with 30s remaining', () {
      expect(controller.state.isRecording, false);
      expect(controller.state.remaining, const Duration(seconds: 30));
      expect(controller.state.elapsed, Duration.zero);
      expect(controller.state.normalizedAmplitude, 0.0);
    });

    test('Normalized amplitude accurately maps -60dBFS to 0.0 and 0dBFS to 1.0', () {
      expect(controller.normalizeDb(-60.0), 0.0);
      expect(controller.normalizeDb(0.0), 1.0);
      expect(controller.normalizeDb(-30.0), closeTo(0.5, 0.01));
      expect(controller.normalizeDb(-80.0), 0.0); // Clamped lower bound
      expect(controller.normalizeDb(10.0), 1.0);  // Clamped upper bound
    });

    test('30-second boundary triggers automatic recording cutoff', () async {
      controller.startMockRecording();
      await Future.delayed(const Duration(milliseconds: 250));
      controller.fastForwardTimer(const Duration(seconds: 30));

      expect(controller.state.isLimitReached, true);
      expect(controller.state.isRecording, false);
      expect(controller.state.remaining, Duration.zero);
    });
  });
}

