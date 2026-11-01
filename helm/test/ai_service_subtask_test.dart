import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/ai_service.dart';
import 'package:waypoint/services/needle_engine.dart';

void main() {
  group('AiService extractSubtasksFromAiResponse Tests', () {
    test('extracts from clean JSON array', () {
      const text = '["Design UI", "Write code", "Deploy app"]';
      final result = AiService.extractSubtasksFromAiResponse(text);
      expect(result, equals(['Design UI', 'Write code', 'Deploy app']));
    });

    test('extracts from markdown code block array', () {
      const text = '```json\n["Step 1", "Step 2"]\n```';
      final result = AiService.extractSubtasksFromAiResponse(text);
      expect(result, equals(['Step 1', 'Step 2']));
    });

    test('extracts from JSON object with subtasks array', () {
      const text = '''
{
  "title": "Build feature",
  "description": "Details",
  "subtasks": ["Milestone 1", "Milestone 2", "Milestone 3"]
}
''';
      final result = AiService.extractSubtasksFromAiResponse(text);
      expect(result, equals(['Milestone 1', 'Milestone 2', 'Milestone 3']));
    });

    test('handles brackets in title and description without crashing or slicing error', () {
      const text = '''
{
  "title": "Fix issue [BUG-101] in auth",
  "description": "See [PR-42] and [RFC-8] for notes",
  "subtasks": [
    "Reproduce bug in staging",
    "Apply security patch",
    "Verify regression tests"
  ]
}
''';
      final result = AiService.extractSubtasksFromAiResponse(text);
      expect(result.length, equals(3));
      expect(result[0], equals('Reproduce bug in staging'));
      expect(result[1], equals('Apply security patch'));
      expect(result[2], equals('Verify regression tests'));
    });

    test('returns empty list for non-JSON or invalid response', () {
      const text = 'I could not generate subtasks for this task.';
      final result = AiService.extractSubtasksFromAiResponse(text);
      expect(result, isEmpty);
    });
  });

  group('NeedleEngine Subtask Decomposition Tests', () {
    late LocalHeuristicParser engine;

    setUp(() async {
      engine = LocalHeuristicParser();
      await engine.initialize();
    });

    test('Extracts subtasks from colon-separated list', () async {
      final result = await engine.extractTask(
        input: 'Prepare product launch: design assets, deploy backend, write release notes',
      );

      expect(result, isNotNull);
      expect(result!['title'], equals('Prepare product launch'));
      final subtasks = result['subtasks'] as List<String>;
      expect(subtasks.length, equals(3));
      expect(subtasks[0], equals('design assets'));
      expect(subtasks[1], equals('deploy backend'));
      expect(subtasks[2], equals('write release notes'));
    });

    test('Preserves compound phrases containing "and" in delimiter list', () async {
      final result = await engine.extractTask(
        input: 'Sprint Launch: QA and test auth, deploy edge functions, and verify metrics',
      );

      expect(result, isNotNull);
      expect(result!['title'], equals('Sprint Launch'));
      final subtasks = result['subtasks'] as List<String>;
      expect(subtasks.length, equals(3));
      expect(subtasks[0], equals('QA and test auth'));
      expect(subtasks[1], equals('deploy edge functions'));
      expect(subtasks[2], equals('verify metrics'));
    });

    test('Extracts subtasks from multi-step sequential phrases without trailing commas', () async {
      final result = await engine.extractTask(
        input: 'First book conference room, then invite team members, and finally print agendas',
      );

      expect(result, isNotNull);
      final subtasks = result!['subtasks'] as List<String>;
      expect(subtasks.length, equals(3));
      expect(subtasks[0], equals('book conference room'));
      expect(subtasks[1], equals('invite team members'));
      expect(subtasks[2], equals('print agendas'));
      expect(result['title'], equals('Book conference room & next steps'));
    });

    test('Extracts prefix project title from multi-step sequential phrases', () async {
      final result = await engine.extractTask(
        input: 'Prepare annual summit: first book venue, then invite speakers, and finally print badges',
      );

      expect(result, isNotNull);
      expect(result!['title'], equals('Prepare annual summit'));
      final subtasks = result['subtasks'] as List<String>;
      expect(subtasks.length, equals(3));
      expect(subtasks[0], equals('book venue'));
      expect(subtasks[1], equals('invite speakers'));
      expect(subtasks[2], equals('print badges'));
    });

    test('Extracts subtasks from bullet-point list', () async {
      final input = '''
Website Redesign
- Create figma wireframes
- Review user journeys
- Implement responsive layout
''';

      final result = await engine.extractTask(input: input);

      expect(result, isNotNull);
      expect(result!['title'], equals('Website Redesign'));
      final subtasks = result['subtasks'] as List<String>;
      expect(subtasks.length, equals(3));
      expect(subtasks[0], equals('Create figma wireframes'));
      expect(subtasks[1], equals('Review user journeys'));
      expect(subtasks[2], equals('Implement responsive layout'));
    });

    test('expandSubtasks returns templateHints when provided', () async {
      final hints = ['Task A', 'Task B', 'Task C'];
      final expanded = await engine.expandSubtasks(
        title: 'Arbitrary Task',
        templateHints: hints,
      );

      expect(expanded, equals(hints));
    });

    test('expandSubtasks returns intelligent fallback milestones based on keywords', () async {
      final launchSteps = await engine.expandSubtasks(
        title: 'Launch Waypoint App',
        templateHints: [],
      );
      expect(launchSteps.length, greaterThanOrEqualTo(3));
      expect(launchSteps.any((s) => s.toLowerCase().contains('rollout') || s.toLowerCase().contains('checklist')), isTrue);

      final testSteps = await engine.expandSubtasks(
        title: 'Test Audio Recording Module',
        templateHints: [],
      );
      expect(testSteps.length, greaterThanOrEqualTo(3));
      expect(testSteps.any((s) => s.toLowerCase().contains('test')), isTrue);

      final bugSteps = await engine.expandSubtasks(
        title: 'Fix critical crash bug on login',
        templateHints: [],
      );
      expect(bugSteps.length, greaterThanOrEqualTo(3));
      expect(bugSteps.any((s) => s.toLowerCase().contains('root cause') || s.toLowerCase().contains('patch')), isTrue);
    });
  });
}
