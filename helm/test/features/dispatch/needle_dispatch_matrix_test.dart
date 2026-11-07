// test/features/dispatch/needle_dispatch_matrix_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_dispatch_engine.dart';
import 'package:waypoint/features/task/domain/models/task.dart';

void main() {
  group('Test Suite 4: Dispatch Filtering & Briefing Compilation', () {
    final now = DateTime(2026, 11, 7, 8, 0, 0);

    test('Scenario A-C: Verifies filtering matrix, isolation of critical items, aggregated counts, and title omission for medium/low tasks', () {
      // Scenario A: Provide 1 overdue item, 1 due today, 2 medium-priority due in 2 days, and 3 low-priority items
      final overdueTask = Task(
        id: 'task_overdue',
        title: 'Fix broken production login gate',
        dueDate: now.subtract(const Duration(hours: 3)),
        priority: TaskPriority.high,
      );

      final todayTask = Task(
        id: 'task_today',
        title: 'Submit daily deployment metrics',
        dueDate: now.add(const Duration(hours: 4)),
        priority: TaskPriority.medium,
      );

      final mediumTask1 = Task(
        id: 'task_medium_1',
        title: 'Review team PR feedback',
        dueDate: now.add(const Duration(days: 2)),
        priority: TaskPriority.medium,
      );

      final mediumTask2 = Task(
        id: 'task_medium_2',
        title: 'Refactor audio service bindings',
        dueDate: now.add(const Duration(days: 2)),
        priority: TaskPriority.medium,
      );

      final lowTask1 = Task(
        id: 'task_low_1',
        title: 'Update documentation typography',
        dueDate: now.add(const Duration(days: 5)),
        priority: TaskPriority.low,
      );

      final lowTask2 = Task(
        id: 'task_low_2',
        title: 'Reorganize scratch files',
        dueDate: now.add(const Duration(days: 6)),
        priority: TaskPriority.low,
      );

      final lowTask3 = Task(
        id: 'task_low_3',
        title: 'Check release badge colors',
        dueDate: now.add(const Duration(days: 7)),
        priority: TaskPriority.low,
      );

      final allTasks = [
        overdueTask,
        todayTask,
        mediumTask1,
        mediumTask2,
        lowTask1,
        lowTask2,
        lowTask3,
      ];

      // Scenario B: Filter engine isolates 2 critical items, summarizes 2 medium tasks, and 3 low tasks
      final summary = NeedleDispatchEngine.filter(allTasks, now);

      expect(summary.criticalTasks.length, 2);
      expect(summary.criticalTasks.map((t) => t.id), containsAll(['task_overdue', 'task_today']));
      expect(summary.mediumCount, 2);
      expect(summary.lowCount, 3);

      final briefingScript = NeedleDispatchEngine.compileBriefingScript(summary);

      // Verify critical items are read by title
      expect(briefingScript, contains('Fix broken production login gate'));
      expect(briefingScript, contains('Submit daily deployment metrics'));

      // Verify counts are summarized accurately
      expect(briefingScript, contains('You have 2 medium tasks due in the next few days'));
      expect(briefingScript, contains('There are 3 low priority items on your horizon'));

      // Scenario C: Ensure final synthesized briefing string OMITS individual titles for medium and low tasks
      expect(briefingScript.contains('Review team PR feedback'), isFalse);
      expect(briefingScript.contains('Refactor audio service bindings'), isFalse);
      expect(briefingScript.contains('Update documentation typography'), isFalse);
      expect(briefingScript.contains('Reorganize scratch files'), isFalse);
      expect(briefingScript.contains('Check release badge colors'), isFalse);
    });
  });
}

