// lib/features/task/domain/models/extracted_task_result.dart

class ExtractedTaskResult {
  final String title;
  final String description;
  final DateTime? dueDate;
  final String priority; // 'urgent' | 'high' | 'medium' | 'low'
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
}

class ExtractedSubtask {
  final String title;
  final DateTime? dueDate;
  const ExtractedSubtask({required this.title, this.dueDate});
}

