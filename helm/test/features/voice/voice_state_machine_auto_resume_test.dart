// test/features/voice/voice_state_machine_auto_resume_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';
import 'package:waypoint/features/voice/domain/controllers/voice_session_controller.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Test Suite 2: State Machine Auto-Resume Verification', () {
    late TaskExtractionParser parser;

    setUp(() {
      parser = TaskExtractionParser(
        anchor: DateTime.parse('2026-11-05T10:00:00+05:30'),
      );
    });

    test(
        'Scenario A-D: Strict sequential state progression, auto-resume, and 30s timer reset upon TTS completion',
        () async {
      final mockTts = MockTtsService(autoComplete: false);
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: mockTts,
      );

      // Start call
      controller.startCall();
      expect(controller.state, VoiceSessionState.listening);
      expect(controller.status, VoiceSessionStatus.userListening);

      // Scenario A: Transition controller to processing state with missing task details
      final processFuture = controller.processUserInput('Review pull request for backend auth');

      // Scenario B: Controller transitions to agent speaking state and triggers speech generation
      expect(controller.status, VoiceSessionStatus.agentSpeaking);
      expect(controller.isSpeakingDisambiguation, isTrue);
      expect(mockTts.isSpeaking, isTrue);
      expect(controller.lastQuestion, isNotNull);

      // Scenario C: Simulate playback completion signal -> auto-transitions back to user listening
      mockTts.completeSpeaking();
      await processFuture;

      expect(controller.state, VoiceSessionState.listening);
      expect(controller.status, VoiceSessionStatus.userListening);
      expect(controller.isListening, isTrue);

      // Scenario D: Confirm recording timer resets to 30 seconds upon re-entering user listening
      expect(controller.remaining.inSeconds, 30);
      expect(controller.remaining, const Duration(seconds: 30));

      controller.dispose();
    });
  });
}

