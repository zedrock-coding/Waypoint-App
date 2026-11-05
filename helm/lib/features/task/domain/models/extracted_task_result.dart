// lib/features/task/domain/models/extracted_task_result.dart

import 'task.dart';

class TaskPriorityValue {
  final TaskPriority enumValue;
  const TaskPriorityValue(this.enumValue);

  String get name => enumValue.name;

  String toLowerCase() => enumValue.name.toLowerCase();
  String toUpperCase() => enumValue.name.toUpperCase();

  @override
  bool operator ==(Object other) {
    if (other is TaskPriority) return other == enumValue;
    if (other is String) return other.toLowerCase() == enumValue.name.toLowerCase();
    if (other is TaskPriorityValue) return other.enumValue == enumValue;
    return false;
  }

  @override
  int get hashCode => enumValue.hashCode;

  @override
  String toString() => enumValue.name;
}

class ExtractedTaskResult {
  final String title;
  final String description;
  final DateTime? dueDate;
  final dynamic priority;
  final List<ExtractedSubtask> subtasks;
  final List<String> missingFields;
  final String? disambiguationPrompt;

  const ExtractedTaskResult({
    required this.title,
    required this.description,
    this.dueDate,
    required this.priority,
    required this.subtasks,
    required this.missingFields,
    this.disambiguationPrompt,
  });

  TaskPriority get taskPriority {
    if (priority is TaskPriority) return priority as TaskPriority;
    if (priority is TaskPriorityValue) return (priority as TaskPriorityValue).enumValue;
    switch (priority.toString().toLowerCase()) {
      case 'urgent':
      case 'critical':
        return TaskPriority.urgent;
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }

  Task toTask({String? id}) {
    return Task(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: description,
      dueDate: dueDate,
      priority: taskPriority,
      subtasks: subtasks
          .map((s) => TaskSubtask(title: s.title, dueDate: s.dueDate))
          .toList(),
    );
  }
}

class ExtractedSubtask {
  final String title;
  final DateTime? dueDate;
  const ExtractedSubtask({required this.title, this.dueDate});
}
