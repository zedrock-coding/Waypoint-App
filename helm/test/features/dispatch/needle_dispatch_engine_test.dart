// test/features/dispatch/needle_dispatch_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_dispatch_engine.dart';
import 'package:waypoint/features/task/domain/models/task.dart';

void main() {
  group('NeedleDispatchEngine Tests', () {
    final now = DateTime(2026, 11, 3, 9, 0); // Reference time

    test('Correctly separates Critical, Medium Horizon, and Low Priority counts', () {
      final tasks = [
        // Critical: Overdue
        Task(id: '1', title: 'Overdue report', dueDate: now.subtract(const Duration(hours: 2)), priority: TaskPriority.low),
        // Critical: Due today
        Task(id: '2', title: 'Team standup', dueDate: now.add(const Duration(hours: 3)), priority: TaskPriority.medium),
        // Critical: Priority urgent regardless of date
        Task(id: '3', title: 'Fix prod bug', dueDate: now.add(const Duration(days: 10)), priority: TaskPriority.urgent),
        // Medium: In 2 days, medium priority
        Task(id: '4', title: 'Review specs', dueDate: now.add(const Duration(days: 2)), priority: TaskPriority.medium),
        // Low: In 5 days, medium priority (beyond 3-day window)
        Task(id: '5', title: 'Long range plan', dueDate: now.add(const Duration(days: 5)), priority: TaskPriority.medium),
        // Low: Low priority
        Task(id: '6', title: 'Clean desk', dueDate: now.add(const Duration(days: 1)), priority: TaskPriority.low),
      ];

      final summary = NeedleDispatchEngine.filter(tasks, now);

      expect(summary.criticalTasks.length, 3);
      expect(summary.criticalTasks.map((t) => t.id), containsAll(['1', '2', '3']));
      expect(summary.mediumCount, 1); // Only Task '4'
      expect(summary.lowCount, 2);    // Tasks '5' and '6'
    });

    test('Briefing script compiles exactly as specified', () {
      final tasks = [
        Task(id: '1', title: 'Sponsorship outreach', dueDate: now.add(const Duration(hours: 1)), priority: TaskPriority.high),
        Task(id: '2', title: 'Sprint retrospective', dueDate: now.add(const Duration(days: 2)), priority: TaskPriority.medium),
        Task(id: '3', title: 'Archive logs', dueDate: now.add(const Duration(days: 10)), priority: TaskPriority.low),
      ];

      final summary = NeedleDispatchEngine.filter(tasks, now);
      final script = NeedleDispatchEngine.compileBriefingScript(summary);

      expect(script, contains("You have 1 critical items: Sponsorship outreach."));
      expect(script, contains("You have 1 medium tasks due in the next few days."));
      expect(script, contains("There are 1 low priority items on your horizon."));
      expect(script.contains("Sprint retrospective"), false); // Medium titles omitted
      expect(script.contains("Archive logs"), false);         // Low titles omitted
    });
  });
}

