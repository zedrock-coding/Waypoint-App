import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';
import 'package:waypoint/features/voice/domain/controllers/voice_session_controller.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';

void main() {
  group('Call-Style Conversational Loop and Disambiguation Tests', () {
    late TaskExtractionParser parser;

    setUp(() {
      parser = TaskExtractionParser(
        anchor: DateTime.parse('2026-11-05T10:00:00+05:30'),
      );
    });

    test('Test 1: Feed partial input lacking time -> verify controller transitions to SpeakingDisambiguation state', () async {
      final mockTts = MockTtsService(autoComplete: false);
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: mockTts,
      );

      controller.startCall();
      expect(controller.state, VoiceSessionState.listening);

      // User speaks a command without due date/time
      final future = controller.processUserInput('Review pull request for backend auth');

      // Controller should detect missing time and transition to speakingDisambiguation
      expect(controller.state, VoiceSessionState.speakingDisambiguation);
      expect(controller.status, VoiceSessionStatus.agentSpeaking);
      expect(controller.isSpeakingDisambiguation, isTrue);
      expect(controller.lastQuestion, isNotNull);
      expect(mockTts.isSpeaking, isTrue);

      mockTts.completeSpeaking();
      await future;
      controller.dispose();
    });

    test('Test 2: Mock TTS completion event -> verify controller automatically transitions to Listening state without manual intervention', () async {
      final mockTts = MockTtsService(autoComplete: false);
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: mockTts,
      );

      controller.startCall();
      expect(controller.state, VoiceSessionState.listening);

      // Start processing missing input
      final future = controller.processUserInput('Prepare slide deck for quarterly review');
      expect(controller.state, VoiceSessionState.speakingDisambiguation);
      expect(mockTts.isSpeaking, isTrue);

      // Mock TTS playback finishing
      mockTts.completeSpeaking();
      await future;

      // Controller must automatically re-open listening without any button press
      expect(controller.state, VoiceSessionState.listening);
      expect(controller.status, VoiceSessionStatus.userListening);
      expect(controller.isListening, isTrue);
      expect(controller.currentChunkIndex, 1);
      expect(controller.remaining.inSeconds, 30);

      controller.dispose();
    });

    test('Test 3: Feed disambiguation response -> verify fields merge and session terminates with TaskCreated', () async {
      final mockTts = MockTtsService(autoComplete: false);
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: mockTts,
      );

      controller.startCall();

      // Chunk 0: Partial input without time
      final futureChunk0 = controller.processUserInput('Fix production authentication bug');
      expect(controller.state, VoiceSessionState.speakingDisambiguation);
      mockTts.completeSpeaking();
      await futureChunk0;

      expect(controller.state, VoiceSessionState.listening);

      // Chunk 1: User provides the missing schedule and priority
      final futureChunk1 = controller.processUserInput('make it high priority and due today evening');
      expect(controller.state, VoiceSessionState.taskCreated);
      expect(controller.isTaskCreated, isTrue);
      expect(controller.confirmationMessage, contains('Fix production authentication bug'));

      mockTts.completeSpeaking();
      await futureChunk1;

      // Verify merged task result
      expect(controller.currentTaskResult, isNotNull);
      expect(controller.currentTaskResult!.priority, 'high');
      expect(controller.currentTaskResult!.dueDate, DateTime.parse('2026-11-05T18:00:00+05:30'));
      expect(controller.currentTaskResult!.missingFields, isEmpty);

      controller.dispose();
    });
  });
}

