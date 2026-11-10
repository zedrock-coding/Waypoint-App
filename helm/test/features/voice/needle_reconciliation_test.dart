import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/needle_reconciliation_engine.dart';

void main() {
  group('NeedleReconciliationEngine Deterministic Tests', () {
    final testAnchor = DateTime.parse('2026-11-10T14:30:00');
    final contextHeader = <String, dynamic>{
      'client_timestamp': testAnchor.toIso8601String(),
      'client_timezone': 'Asia/Kolkata',
      'current_user': 'user_123',
      'accessible_members': [
        {'id': 'member_alex', 'full_name': 'Alex Rivera'},
        {'id': 'member_sarah', 'full_name': 'Sarah Chen'},
      ],
      'accessible_communities': [
        {'id': 'comm_infra', 'name': 'Infrastructure Team'},
      ],
    };

    test('Rule 1: Strips imperative meta-framing from title', () {
      final preliminaryJson = {
        'title': 'create a task saying Deploy hotfix for authentication regression',
        'due_date': null,
        'priority': 'MEDIUM',
        'subtasks': [],
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: 'please create a task saying Deploy hotfix for authentication regression',
        geminiTaskJson: preliminaryJson,
        contextHeader: contextHeader,
      );

      expect(result.status, 'verified');
      expect(result.task['title'], 'Deploy hotfix for authentication regression');
      expect(result.reconciliationLog.any((l) => l.contains('Sanitized')), isTrue);
    });

    test('Rule 2: Resolves relative date "tonight" against client timestamp anchor', () {
      final preliminaryJson = {
        'title': 'Server maintenance',
        'due_date': '2026-11-10',
        'priority': 'HIGH',
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: 'remind me to do server maintenance tonight',
        geminiTaskJson: preliminaryJson,
        contextHeader: contextHeader,
      );

      expect(result.status, 'verified');
      expect(result.task['title'], 'Server maintenance');
      final dueDate = DateTime.parse(result.task['due_date']);
      expect(dueDate.year, 2026);
      expect(dueDate.month, 11);
      expect(dueDate.day, 10);
      expect(dueDate.hour, 21);
      expect(dueDate.minute, 0);
    });

    test('Rule 2b: Resolves "tomorrow morning" against client timestamp anchor', () {
      final preliminaryJson = {
        'title': 'Sprint Review',
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: 'Schedule sprint review for tomorrow morning',
        geminiTaskJson: preliminaryJson,
        contextHeader: contextHeader,
      );

      expect(result.status, 'verified');
      final dueDate = DateTime.parse(result.task['due_date']);
      expect(dueDate.year, 2026);
      expect(dueDate.month, 11);
      expect(dueDate.day, 11); // next day
      expect(dueDate.hour, 9);
      expect(dueDate.minute, 0);
    });

    test('Rule 3: Decomposes sequential clauses into discrete subtasks', () {
      final preliminaryJson = {
        'title': 'Prepare client presentation',
        'subtasks': ['Draft slides'],
      };

      final rawSpeech =
          'First draft the slides, then review with team, also export PDF, finally send to client';

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: rawSpeech,
        geminiTaskJson: preliminaryJson,
        contextHeader: contextHeader,
      );

      expect(result.status, 'verified');
      final subtasks = result.task['subtasks'] as List;
      expect(subtasks.length, greaterThanOrEqualTo(3));
      final titles = subtasks.map((s) => s['title'].toString().toLowerCase()).toList();
      expect(titles.any((t) => t.contains('draft')), isTrue);
      expect(titles.any((t) => t.contains('review')), isTrue);
    });

    test('Rule 4: Normalizes priority levels accurately', () {
      final resultUrgent = NeedleReconciliationEngine.reconcile(
        rawTranscript: 'Deploy database patch asap',
        geminiTaskJson: {'title': 'Deploy database patch', 'priority': 'HIGH'},
        contextHeader: contextHeader,
      );
      expect(resultUrgent.task['priority'], 'urgent');

      final resultLow = NeedleReconciliationEngine.reconcile(
        rawTranscript: 'Clean test logs whenever possible low priority',
        geminiTaskJson: {'title': 'Clean test logs'},
        contextHeader: contextHeader,
      );
      expect(resultLow.task['priority'], 'low');
    });

    test('Rule 5: Resolves spoken member to accessible collaborator ID', () {
      final preliminaryJson = {
        'title': 'Review architecture diagrams',
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: 'Assign review architecture diagrams to Alex Rivera',
        geminiTaskJson: preliminaryJson,
        contextHeader: contextHeader,
      );

      expect(result.status, 'verified');
      expect(result.task['assignee'], 'member_alex');
    });

    test('Rule 6: Triggers clarification_needed when intent/title is missing', () {
      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: '',
        geminiTaskJson: {'title': ''},
        contextHeader: contextHeader,
      );

      expect(result.status, 'clarification_needed');
      expect(result.missingFields, contains('title'));
      expect(result.disambiguationPrompt, isNotNull);
      expect(result.disambiguationPrompt!.isNotEmpty, isTrue);
    });

    test('Rule 6b: Retains draft fields during clarification turn', () {
      final preliminaryJson = {
        'title': 'Call vendor',
        'clarification_needed': true,
        'clarification_message': 'What time should I remind you to call the vendor?',
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: 'Remind me to call vendor',
        geminiTaskJson: preliminaryJson,
        contextHeader: contextHeader,
      );

      expect(result.status, 'clarification_needed');
      expect(result.task['title'], 'Call vendor');
      expect(result.missingFields, contains('due_date'));
      expect(result.disambiguationPrompt, 'What time should I remind you to call the vendor?');
    });
  });
}
