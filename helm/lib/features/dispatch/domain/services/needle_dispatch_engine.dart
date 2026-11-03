// lib/features/dispatch/domain/services/needle_dispatch_engine.dart

import 'package:waypoint/features/task/domain/models/task.dart';

class DispatchSummary {
  final List<Task> criticalTasks;
  final int mediumCount;
  final int lowCount;

  const DispatchSummary({
    required this.criticalTasks,
    required this.mediumCount,
    required this.lowCount,
  });
}

class NeedleDispatchEngine {
  static DispatchSummary filter(List<Task> allPendingTasks, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));
    final mediumHorizon = startOfToday.add(const Duration(days: 3));

    final List<Task> critical = [];
    int mediumCount = 0;
    int lowCount = 0;

    for (final task in allPendingTasks) {
      final isOverdueOrToday = task.dueDate != null && task.dueDate!.isBefore(endOfToday);
      final isUrgent = task.priority == TaskPriority.urgent;

      if (isUrgent || isOverdueOrToday) {
        critical.add(task);
      } else if (task.priority == TaskPriority.medium &&
          task.dueDate != null &&
          task.dueDate!.isBefore(mediumHorizon)) {
        mediumCount++;
      } else {
        lowCount++;
      }
    }

    return DispatchSummary(
      criticalTasks: critical,
      mediumCount: mediumCount,
      lowCount: lowCount,
    );
  }

  static String compileBriefingScript(DispatchSummary summary) {
    final buffer = StringBuffer();
    buffer.write("Good morning. ");

    if (summary.criticalTasks.isEmpty) {
      buffer.write("You have no critical or overdue tasks today. ");
    } else {
      buffer.write("You have ${summary.criticalTasks.length} critical items: ");
      for (int i = 0; i < summary.criticalTasks.length; i++) {
        final t = summary.criticalTasks[i];
        buffer.write("${t.title}. ");
      }
    }

    if (summary.mediumCount > 0) {
      buffer.write("You have ${summary.mediumCount} medium tasks due in the next few days. ");
    }

    if (summary.lowCount > 0) {
      buffer.write("There are ${summary.lowCount} low priority items on your horizon.");
    }

    return buffer.toString().trim();
  }
}
