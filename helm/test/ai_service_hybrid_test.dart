import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/needle_engine.dart';
import 'package:waypoint/services/ai_service.dart';

void main() {
  group('LocalHeuristicParser Tests', () {
    late LocalHeuristicParser engine;

    setUp(() async {
      engine = LocalHeuristicParser();
      await engine.initialize();
    });

    test('Initializes successfully', () {
      expect(engine.isReady, isTrue);
    });

    test('Extracts urgent priority and tomorrow date correctly', () async {
      final result = await engine.extractTask(
        input: 'Urgent meeting tomorrow morning',
      );

      expect(result, isNotNull);
      expect(result!['priority'], equals('HIGH'));
      expect(result['due_date'], isNotNull);
      expect(result['clarification_needed'], isFalse);
    });

    test('Extracts time at 5 pm correctly', () async {
      final result = await engine.extractTask(
        input: 'Test AI functionality and automation at 5 pm',
      );

      expect(result, isNotNull);
      expect(result!['due_date'], isNotNull);
      expect(result['due_date'].toString(), contains('T17:00:00'));
      expect(result['title'], equals('Test AI functionality and automation'));
    });

    test('Extracts explicit date and time on October 31 at 5 pm', () async {
      final result = await engine.extractTask(
        input: 'Release review on October 31 at 5 pm',
      );

      expect(result, isNotNull);
      expect(result!['due_date'], isNotNull);
      expect(result['due_date'].toString(), contains('-10-31T17:00:00'));
    });

    test('Blends date-only cloud template with user time at 5 pm', () async {
      final cloudTemplate = {
        'title': 'Test AI functionality and automation',
        'due_date': '2026-10-31',
      };

      final result = await engine.extractTask(
        input: 'make the task at 5 pm',
        templateContext: cloudTemplate,
      );

      expect(result, isNotNull);
      expect(result!['due_date'], equals('2026-10-31T17:00:00'));
    });

    test('Extracts low priority and assigns matching community and member', () async {
      final communities = [
        {'id': 'comm-123', 'name': 'Engineering'},
        {'id': 'comm-456', 'name': 'Design'},
      ];
      final members = [
        {'id': 'user-999', 'full_name': 'Sarah Connor'},
      ];

      final result = await engine.extractTask(
        input: 'Minor doc review when possible for engineering with Sarah Connor',
        availableCommunities: communities,
        availableMembers: members,
      );

      expect(result, isNotNull);
      expect(result!['priority'], equals('LOW'));
      expect(result['community_id'], equals('comm-123'));
      expect(result['assignee_id'], equals('user-999'));
    });

    test('Applies Gemini template context with grammar constraints', () async {
      final cloudTemplate = {
        'title': 'De-jumbled Title by Gemini',
        'description': 'Rich summary of rambling speech',
        'priority': 'HIGH',
        'due_date': '2026-11-01',
      };

      final result = await engine.extractTask(
        input: 'Rambling speech transcript',
        templateContext: cloudTemplate,
      );

      expect(result, isNotNull);
      expect(result!['title'], equals('De-jumbled Title by Gemini'));
      expect(result['description'], equals('Rich summary of rambling speech'));
      expect(result['priority'], equals('HIGH'));
      expect(result['due_date'], equals('2026-11-01'));
    });

    test('Preserves clarification_needed and clarification_message in template context', () async {
      final cloudTemplate = {
        'title': 'Call dentist',
        'clarification_needed': true,
        'clarification_message': 'When would you like to schedule the dentist call?',
      };

      final result = await engine.extractTask(
        input: 'Call dentist',
        templateContext: cloudTemplate,
      );

      expect(result, isNotNull);
      expect(result!['clarification_needed'], isTrue);
      expect(result['clarification_message'], equals('When would you like to schedule the dentist call?'));
    });

    test('Expands subtasks correctly', () async {
      final subtasks = await engine.expandSubtasks(
        title: 'Deploy backend service',
        templateHints: ['Build container', 'Run migrations', 'Push to staging'],
      );

      expect(subtasks.length, equals(3));
      expect(subtasks.first, equals('Build container'));
    });

    test('Extracts subtasks from Gemini templateContext', () async {
      final cloudTemplate = {
        'title': 'Sprint Kickoff',
        'subtasks': ['Review backlog', 'Assign tickets', 'Schedule standup'],
      };

      final result = await engine.extractTask(
        input: 'Sprint Kickoff with subtasks',
        templateContext: cloudTemplate,
      );

      expect(result, isNotNull);
      expect(result!['subtasks'], equals(['Review backlog', 'Assign tickets', 'Schedule standup']));
    });

    test('Extracts subtasks offline from colon-separated lists', () async {
      final result = await engine.extractTask(
        input: 'Prep release: bump version, test, deploy',
      );

      expect(result, isNotNull);
      expect(result!['title'], equals('Prep release'));
      expect(result['subtasks'], equals(['bump version', 'test', 'deploy']));
    });
  });

  group('AiService Hybrid Fast-Path Tests', () {
    test('Fast path runs through needle engine without cloud failure', () async {
      final aiService = AiService(needleEngine: LocalHeuristicParser());
      final result = await aiService.parseHybridCommand(
        userInput: 'Urgent fix tomorrow',
        availableCommunities: [],
        availableMembers: [],
      );

      expect(result, isNotNull);
      expect(result!['priority'], equals('HIGH'));
      expect(result['due_date'], isNotNull);
    });
  });

  group('AiService parseAiDueDate Tests', () {
    test('Preserves explicit time from ISO8601 string', () {
      final dt = AiService.parseAiDueDate('2026-10-31T17:00:00');
      expect(dt, isNotNull);
      expect(dt!.year, equals(2026));
      expect(dt.month, equals(10));
      expect(dt.day, equals(31));
      expect(dt.hour, equals(17));
      expect(dt.minute, equals(0));
    });

    test('Defaults date-only string to midday 12:00', () {
      final dt = AiService.parseAiDueDate('2026-10-31');
      expect(dt, isNotNull);
      expect(dt!.year, equals(2026));
      expect(dt.month, equals(10));
      expect(dt.day, equals(31));
      expect(dt.hour, equals(12));
      expect(dt.minute, equals(0));
    });

    test('Applies separate due_time field if provided', () {
      final dt = AiService.parseAiDueDate('2026-10-31', '5:00 PM');
      expect(dt, isNotNull);
      expect(dt!.hour, equals(17));
      expect(dt.minute, equals(0));
    });

    test('Returns null for null or invalid input', () {
      expect(AiService.parseAiDueDate(null), isNull);
      expect(AiService.parseAiDueDate(''), isNull);
      expect(AiService.parseAiDueDate('null'), isNull);
      expect(AiService.parseAiDueDate('not-a-date'), isNull);
    });
  });
}
