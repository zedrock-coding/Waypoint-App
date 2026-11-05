// test/features/dispatch/needle_dispatch_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_dispatch_engine.dart';
import 'package:waypoint/features/task/domain/models/task.dart';

void main() {
  group('Needle Dispatch Briefing Aggregation Tests', () {
    final now = DateTime(2026, 11, 5, 8, 0);

    test('Compiles briefing script with critical details and aggregated medium/low counts', () {
      final tasks = [
        Task(id: '1', title: 'Assist Priyanshi with Jira', dueDate: now.add(const Duration(hours: 10)), priority: TaskPriority.high),
        Task(id: '2', title: 'Sync with frontend lead', dueDate: now.add(const Duration(days: 2)), priority: TaskPriority.medium),
        Task(id: '3', title: 'Archive repo branches', dueDate: now.add(const Duration(days: 6)), priority: TaskPriority.low),
      ];

      final summary = NeedleDispatchEngine.filter(tasks, now);
      final script = NeedleDispatchEngine.compileBriefingScript(summary);

      expect(script, contains('Assist Priyanshi with Jira'));
      expect(script, contains('1 medium tasks due in the next few days'));
      expect(script, contains('1 low priority items on your horizon'));
      expect(script.contains('Sync with frontend lead'), false); // Medium titles aggregated
    });

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
  });
}
