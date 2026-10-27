import 'package:flutter_test/flutter_test.dart';
import 'package:helm/services/needle_engine.dart';
import 'package:helm/services/ai_service.dart';

void main() {
  group('CactusNeedleEngine Tests', () {
    late CactusNeedleEngine engine;

    setUp(() async {
      engine = CactusNeedleEngine();
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
  });

  group('AiService Hybrid Fast-Path Tests', () {
    test('Fast path runs through needle engine without cloud failure', () async {
      final aiService = AiService(needleEngine: CactusNeedleEngine());
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
}
