// lib/features/task/domain/models/task.dart

enum TaskPriority {
  urgent,
  high,
  medium,
  low,
}

class TaskSubtask {
  final String title;
  final DateTime? dueDate;
  final bool isCompleted;

  const TaskSubtask({
    required this.title,
    this.dueDate,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'due_date': dueDate?.toIso8601String(),
        'is_completed': isCompleted,
      };
}

class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final List<TaskSubtask> subtasks;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.subtasks = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority.name,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
      };
}

