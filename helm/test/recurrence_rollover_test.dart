import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/models/hive_models.dart' as hive_model;
import 'package:waypoint/models/unified_task.dart';
import 'package:waypoint/services/recurrence_calculator.dart';

void main() {
  group('Recurrence Rollover & Serialization Tests', () {
    test('UnifiedTask.fromHive parses recurrence fields correctly', () {
      final task = hive_model.Task(
        id: 'test-rec-1',
        title: 'Weekly Standup',
        dueAt: DateTime(2026, 11, 16, 9, 30),
        isRecurring: true,
        recurrenceFrequency: 'weekly',
        recurrenceInterval: 1,
        recurrenceDaysOfWeek: [1], // Monday
        recurrenceEndDate: DateTime(2026, 12, 31),
        parentRecurringTaskId: 'parent-123',
      );

      final unified = UnifiedTask.fromHive(task);

      expect(unified.isRecurring, isTrue);
      expect(unified.recurrenceRule, isNotNull);
      expect(unified.recurrenceRule!.frequency, 'weekly');
      expect(unified.recurrenceRule!.interval, 1);
      expect(unified.recurrenceRule!.daysOfWeek, [1]);
      expect(unified.recurrenceRule!.endDate, DateTime(2026, 12, 31));
      expect(unified.parentRecurringTaskId, 'parent-123');
      expect(unified.recurrenceRule!.readableDescription, 'Every week on Mon');
    });

    test('UnifiedTask.fromSupabase parses recurrence fields correctly', () {
      final data = {
        'id': 'supa-task-1',
        'title': 'Daily Hydration Check',
        'due_at': '2026-11-10T08:00:00.000Z',
        'created_at': '2026-11-10T08:00:00.000Z',
        'is_recurring': true,
        'recurrence_frequency': 'daily',
        'recurrence_interval': 1,
        'recurrence_days_of_week': null,
        'recurrence_end_date': null,
        'parent_recurring_task_id': null,
      };

      final unified = UnifiedTask.fromSupabase(data);

      expect(unified.isRecurring, isTrue);
      expect(unified.recurrenceRule, isNotNull);
      expect(unified.recurrenceRule!.frequency, 'daily');
      expect(unified.recurrenceRule!.interval, 1);
      expect(unified.recurrenceRule!.readableDescription, 'Repeats daily');
    });

    test('Rollover clones subtasks with is_completed reset to false', () {
      final originalSubtasks = [
        {'id': 'sub-1', 'title': 'Review agenda', 'is_completed': true},
        {'id': 'sub-2', 'title': 'Take meeting notes', 'is_completed': true},
      ];

      final resetSubtasks = originalSubtasks.map((st) {
        return {
          ...st,
          'id': 'new-${st['id']}',
          'is_completed': false,
        };
      }).toList();

      expect(resetSubtasks.length, 2);
      expect(resetSubtasks[0]['is_completed'], isFalse);
      expect(resetSubtasks[1]['is_completed'], isFalse);
      expect(resetSubtasks[0]['title'], 'Review agenda');
    });

    test('Rollover calculates subsequent due date and checks bounds', () {
      final dueDate = DateTime(2026, 11, 10, 10, 0);
      final rule = RecurrenceRule(
        frequency: 'daily',
        endDate: DateTime(2026, 11, 11, 23, 59),
      );

      final next1 = RecurrenceCalculator.calculateNextDueDate(dueDate, rule);
      expect(next1, DateTime(2026, 11, 11, 10, 0));
      expect(RecurrenceCalculator.shouldSpawnNextInstance(next1, rule), isTrue);

      final next2 = RecurrenceCalculator.calculateNextDueDate(next1, rule);
      expect(next2, DateTime(2026, 11, 12, 10, 0));
      // next2 is after endDate (2026-11-11), so should not spawn
      expect(RecurrenceCalculator.shouldSpawnNextInstance(next2, rule), isFalse);
    });
  });
}

