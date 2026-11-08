import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';
import 'package:waypoint/features/voice/domain/controllers/voice_session_controller.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Waypoint Voice Remediation & Multi-Turn Verification Tests', () {
    late TaskExtractionParser parser;
    final anchor = DateTime.parse('2026-11-05T10:00:00+05:30'); // Thursday

    setUp(() {
      parser = TaskExtractionParser(anchor: anchor);
    });

    test('1. Temporal Parsing: Weekday extraction properly resolves to future date', () {
      // 2026-11-05 is Thursday. Next Friday is 2026-11-06. Next Monday is 2026-11-09.
      final fridayResult = parser.parse('Prepare deployment checklist on friday');
      expect(fridayResult.dueDate, isNotNull);
      expect(fridayResult.dueDate!.year, 2026);
      expect(fridayResult.dueDate!.month, 11);
      expect(fridayResult.dueDate!.day, 6);

      final mondayResult = parser.parse('Submit quarterly report next monday');
      expect(mondayResult.dueDate, isNotNull);
      expect(mondayResult.dueDate!.year, 2026);
      expect(mondayResult.dueDate!.month, 11);
      expect(mondayResult.dueDate!.day, 9);
    });

    test('2. Temporal Parsing: 12-hour and 24-hour clock notations', () {
      final pmResult = parser.parse('Team sync tomorrow at 5pm');
      expect(pmResult.dueDate, isNotNull);
      expect(pmResult.dueDate, DateTime.parse('2026-11-06T17:00:00+05:30'));

      final amResult = parser.parse('Morning standup tomorrow at 9:30 am');
      expect(amResult.dueDate, isNotNull);
      expect(amResult.dueDate, DateTime.parse('2026-11-06T09:30:00+05:30'));

      final militaryResult = parser.parse('Server maintenance today at 23:45');
      expect(militaryResult.dueDate, isNotNull);
      expect(militaryResult.dueDate, DateTime.parse('2026-11-05T23:45:00+05:30'));
    });

    test('3. Priority Parsing: Standalone priority keywords without explicit word priority', () {
      final urgentResult = parser.parse('Fix hotfix asap tomorrow 5pm');
      expect(urgentResult.priority, 'urgent');

      final highResult = parser.parse('Ship release candidate high tomorrow 5pm');
      expect(highResult.priority, 'high');

      final lowResult = parser.parse('Clean legacy folders low tomorrow 5pm');
      expect(lowResult.priority, 'low');
    });

    test('4. Graceful Default: When deadline is provided, priority defaults to medium without extra turn', () {
      final result = parser.parse('Review pull request tomorrow at 3pm');
      expect(result.dueDate, isNotNull);
      expect(result.priority, 'medium');
      // Should not block or ask for priority when due date is present
      expect(result.missingFields, isEmpty);
      expect(result.disambiguationPrompt, isNull);
    });

    test('5. Symmetrical Context Tracking: Records both user and assistant utterances', () async {
      final mockTts = MockTtsService(autoComplete: false);
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: mockTts,
      );

      controller.startCall();
      expect(controller.conversationHistory, isEmpty);

      // User speaks first turn without deadline
      final future = controller.processUserInput('Refactor payment processor module');
      expect(controller.conversationHistory.length, 2);
      expect(controller.conversationHistory[0]['role'], 'user');
      expect(controller.conversationHistory[0]['content'], 'Refactor payment processor module');
      expect(controller.conversationHistory[1]['role'], 'assistant');
      expect(controller.conversationHistory[1]['content'], isNotEmpty);

      mockTts.completeSpeaking();
      await future;

      // User speaks second turn answering with deadline
      final future2 = controller.processUserInput('due tomorrow at 4pm');
      expect(controller.conversationHistory.length, 4);
      expect(controller.conversationHistory[2]['role'], 'user');
      expect(controller.conversationHistory[2]['content'], 'due tomorrow at 4pm');
      expect(controller.conversationHistory[3]['role'], 'assistant');
      expect(controller.conversationHistory[3]['content'], contains('Refactor payment processor module'));

      mockTts.completeSpeaking();
      await future2;

      expect(controller.isTaskCreated, isTrue);
      controller.dispose();
    });

    test('6. Draft Delta-Merging: Preserves title across multi-turn disambiguation answers', () async {
      final mockTts = MockTtsService(autoComplete: false);
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: mockTts,
      );

      controller.startCall();

      // Turn 1: User provides task title only
      final turn1 = controller.processUserInput('Audit cloud security policies');
      mockTts.completeSpeaking();
      await turn1;

      expect(controller.currentTaskResult, isNotNull);
      expect(controller.currentTaskResult!.title, 'Audit cloud security policies');

      // Turn 2: User provides only time and priority
      final turn2 = controller.processUserInput('make it high and due tomorrow at 2pm');
      mockTts.completeSpeaking();
      await turn2;

      // Verifies title was preserved via delta-merging and not overwritten by 'make it high...'
      expect(controller.currentTaskResult!.title, 'Audit cloud security policies');
      expect(controller.currentTaskResult!.priority, 'high');
      expect(controller.currentTaskResult!.dueDate, isNotNull);
      expect(controller.isTaskCreated, isTrue);

      controller.dispose();
    });
  });
}
