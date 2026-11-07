// test/features/voice/voice_watchdog_failsafe_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';
import 'package:waypoint/features/voice/domain/controllers/voice_session_controller.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';

/// Mock TTS engine that simulates a dropped completion event (hangs indefinitely)
class HangingMockTtsService implements ITextToSpeechService {
  bool _isSpeaking = false;
  final Completer<void> _hangCompleter = Completer<void>();

  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    _isSpeaking = true;
    // Intentionally drops completion event - never resolves on its own
    await _hangCompleter.future;
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    if (!_hangCompleter.isCompleted) {
      _hangCompleter.complete();
    }
  }

  @override
  void dispose() {
    stop();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Test Suite 3: Watchdog Failsafe Verification', () {
    late TaskExtractionParser parser;

    setUp(() {
      parser = TaskExtractionParser(
        anchor: DateTime.parse('2026-11-05T10:00:00+05:30'),
      );
    });

    test(
        'Scenario A-B: Dropped completion event triggers watchdog timer to safely recover to user listening state without freezing',
        () async {
      final hangingTts = HangingMockTtsService();

      // Configure a fast 150ms watchdog for test execution
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: hangingTts,
        watchdogDuration: const Duration(milliseconds: 150),
      );

      controller.startCall();
      expect(controller.status, VoiceSessionStatus.userListening);

      // Scenario A: Start processing input that requires disambiguation; playback player drops completion
      final future = controller.processUserInput('Prepare quarterly report');

      // Controller enters agent speaking state
      expect(controller.status, VoiceSessionStatus.agentSpeaking);
      expect(hangingTts.isSpeaking, isTrue);

      // Scenario B: Wait for watchdog timeout to trigger
      await Future.delayed(const Duration(milliseconds: 250));
      await future;

      // Verify watchdog recovered the state safely
      expect(controller.watchdogFired, isTrue);
      expect(controller.status, VoiceSessionStatus.userListening);
      expect(controller.state, VoiceSessionState.listening);
      expect(controller.remaining.inSeconds, inInclusiveRange(28, 30));
      expect(hangingTts.isSpeaking, isFalse);

      controller.dispose();
    });
  });
}

