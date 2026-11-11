import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/needle_reconciliation_engine.dart';

void main() {
  group('Multi-Task AI Extraction & Reconciliation Tests', () {
    final anchor = DateTime(2026, 11, 9, 10, 0); // Monday
    final contextHeader = {
      'client_timestamp': anchor.toIso8601String(),
      'client_timezone': 'UTC',
      'accessible_members': <Map<String, dynamic>>[],
      'accessible_communities': <Map<String, dynamic>>[],
    };

    test('Reconciles 2 distinct tasks with independent recurrence and dates', () {
      final rawTranscript =
          'Draft the partnership agreement by Wednesday, and remind me every Monday morning to review sprint analytics';

      final geminiPayload = {
        'transcript': rawTranscript,
        'tasks': [
          {
            'temp_id': 'task_1',
            'title': 'Draft the partnership agreement',
            'description': 'Partnership agreement draft',
            'due_date': '2026-11-11T17:00:00',
            'priority': 'HIGH',
            'is_recurring': false,
            'recurrence_rule': null,
            'subtasks': ['Review terms', 'Circulate to counsel'],
          },
          {
            'temp_id': 'task_2',
            'title': 'Review sprint analytics',
            'description': 'Weekly sprint analytics',
            'due_date': '2026-11-16T09:00:00',
            'priority': 'MEDIUM',
            'is_recurring': true,
            'recurrence_rule': {
              'frequency': 'weekly',
              'interval': 1,
              'days_of_week': [1],
            },
            'subtasks': [],
          },
        ],
        'clarification_needed': false,
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: rawTranscript,
        geminiTaskJson: geminiPayload,
        contextHeader: contextHeader,
      );

      expect(result.status, 'verified');
      expect(result.tasks.length, 2);

      // Task 1 assertions
      final task1 = result.tasks[0];
      expect(task1['title'].toString().toLowerCase(), contains('partnership agreement'));
      expect(task1['priority'], 'high');
      expect(task1['is_recurring'], isFalse);
      expect((task1['subtasks'] as List).length, 2);

      // Task 2 assertions
      final task2 = result.tasks[1];
      expect(task2['title'].toString().toLowerCase(), contains('review sprint analytics'));
      expect(task2['priority'], 'medium');
      expect(task2['is_recurring'], isTrue);
      expect(task2['recurrence_rule']['frequency'], 'weekly');
      expect(task2['recurrence_rule']['days_of_week'], [1]);
    });

    test('Multi-task with missing field generates targeted compound disambiguation prompt', () {
      final rawTranscript =
          'Draft the partnership agreement by Wednesday, and also review sprint analytics';

      final geminiPayload = {
        'transcript': rawTranscript,
        'tasks': [
          {
            'temp_id': 'task_1',
            'title': 'Draft partnership agreement',
            'due_date': '2026-11-11T17:00:00',
            'priority': 'HIGH',
          },
          {
            'temp_id': 'task_2',
            'title': 'Review sprint analytics',
            'due_date': null, // Missing due date
            'priority': 'MEDIUM',
          },
        ],
        'clarification_needed': true,
        'clarification_message':
            'I have scheduled the partnership agreement for Wednesday. When should the sprint analytics review be due?',
        'disambiguation_questionnaire': [
          {
            'target_temp_id': 'task_2',
            'missing_field': 'due_date',
            'prompt': 'When should the sprint analytics review be due?',
          }
        ],
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: rawTranscript,
        geminiTaskJson: geminiPayload,
        contextHeader: contextHeader,
      );

      expect(result.status, 'clarification_needed');
      expect(result.tasks.length, 2);
      expect(result.disambiguationPrompt, contains('sprint analytics'));
    });

    test('Single task with subtasks is preserved as 1 top-level task with milestones', () {
      final rawTranscript =
          'Help Priyanshi by first configuring Jira, second setting up email, and finally verifying permissions';

      final geminiPayload = {
        'transcript': rawTranscript,
        'title': 'Help Priyanshi onboard',
        'due_date': '2026-11-10T18:00:00',
        'priority': 'MEDIUM',
        'subtasks': [
          {'title': 'Configuring Jira', 'completed': false},
          {'title': 'Setting up email', 'completed': false},
          {'title': 'Verifying permissions', 'completed': false},
        ],
      };

      final result = NeedleReconciliationEngine.reconcile(
        rawTranscript: rawTranscript,
        geminiTaskJson: geminiPayload,
        contextHeader: contextHeader,
      );

      expect(result.status, 'verified');
      expect(result.tasks.length, 1);
      expect((result.task['subtasks'] as List).length, greaterThanOrEqualTo(3));
    });
  });
}
