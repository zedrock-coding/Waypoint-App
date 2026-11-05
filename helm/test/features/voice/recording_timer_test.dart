import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/voice/domain/controllers/audio_capture_controller.dart';

void main() {
  group('Recording Countdown Timer and State Tests', () {
    test('Test 1: Start recording; verify the stream emits monotonically decreasing remaining duration', () async {
      final controller = AudioCaptureController(maxDuration: const Duration(seconds: 30));
      final emittedRemaining = <Duration>[];

      final subscription = controller.stream.listen((state) {
        emittedRemaining.add(state.remaining);
      });

      controller.startRecording();

      // Allow several 50ms periodic timer ticks to elapse
      await Future.delayed(const Duration(milliseconds: 220));

      await subscription.cancel();
      controller.stop();
      controller.dispose();

      // Verify multiple ticks occurred
      expect(emittedRemaining.length, greaterThanOrEqualTo(3));

      // Initial remaining should be 30s
      expect(emittedRemaining.first, const Duration(seconds: 30));

      // Verify remaining duration is monotonically decreasing
      for (int i = 1; i < emittedRemaining.length; i++) {
        expect(
          emittedRemaining[i] <= emittedRemaining[i - 1],
          isTrue,
          reason: 'Emission $i (${emittedRemaining[i]}) should be <= previous (${emittedRemaining[i - 1]})',
        );
      }

      // Verify final emission is strictly less than initial
      expect(emittedRemaining.last < emittedRemaining.first, isTrue);
    });

    test('Test 2: Fast-forward time to 30.0s; verify isLimitReached == true and recording is stopped automatically', () async {
      final controller = AudioCaptureController(maxDuration: const Duration(seconds: 30));
      bool autoSubmitFired = false;

      controller.startRecording(
        onLimitReached: () {
          autoSubmitFired = true;
        },
      );

      expect(controller.isRecording, isTrue);
      expect(controller.isLimitReached, isFalse);
      expect(controller.state.remaining, const Duration(seconds: 30));

      // Fast forward by 30 seconds
      controller.fastForwardTimer(const Duration(seconds: 30));

      // Verify hard ceiling auto-cutoff
      expect(controller.isLimitReached, isTrue);
      expect(controller.state.isLimitReached, isTrue);
      expect(controller.isRecording, isFalse);
      expect(controller.state.isRecording, isFalse);
      expect(controller.state.remaining, Duration.zero);
      expect(controller.state.elapsed, const Duration(seconds: 30));
      expect(controller.isTickerActive, isFalse);
      expect(autoSubmitFired, isTrue);

      controller.dispose();
    });

    test('Test 3: Stopping recording resets the stopwatch and cancels the periodic ticker', () async {
      final controller = AudioCaptureController(maxDuration: const Duration(seconds: 30));

      controller.startRecording();
      expect(controller.isRecording, isTrue);
      expect(controller.isTickerActive, isTrue);
      expect(controller.stopwatch.isRunning, isTrue);

      // Wait 100ms so stopwatch accumulates time
      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.stopwatch.elapsedMilliseconds, greaterThan(0));

      controller.stop();

      // Verify controller state is reset
      expect(controller.isRecording, isFalse);
      expect(controller.state.isRecording, isFalse);
      expect(controller.isTickerActive, isFalse);
      expect(controller.ticker, isNull);

      // Verify stopwatch is stopped and reset
      expect(controller.stopwatch.isRunning, isFalse);
      expect(controller.stopwatch.elapsed, Duration.zero);
      expect(controller.state.elapsed, Duration.zero);
      expect(controller.state.remaining, const Duration(seconds: 30));

      controller.dispose();
    });
  });
}
