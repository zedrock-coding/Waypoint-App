import 'hive_models.dart' as hive_model;

enum Priority { low, medium, high }
enum Status { toDo, inProgress, done }

class UnifiedTask {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final bool isCompleted;
  final Status status;
  final String? communityId;
  final String? categoryId;
  final Priority priority;
  final List<String> assignees;
  final bool isLocal; 

  UnifiedTask({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.isCompleted,
    required this.status,
    this.communityId,
    this.categoryId,
    required this.priority,
    required this.assignees,
    required this.isLocal,
  });

  factory UnifiedTask.fromHive(hive_model.Task task) {
    return UnifiedTask(
      id: task.id,
      title: task.title,
      description: task.description ?? '',
      dateTime: task.dueAt ?? task.createdAt,
      isCompleted: task.isCompleted,
      status: _parseStatus(task.status ?? 'toDo'),
      communityId: task.communityId,
      categoryId: task.categoryId,
      priority: _parsePriority(task.priority ?? 'medium'),
      assignees: List.from(task.assignees ?? []),
      isLocal: task.communityId == null, 
    );
  }

  factory UnifiedTask.fromSupabase(Map<String, dynamic> data) {
    return UnifiedTask(
      id: data['id'].toString(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dateTime: DateTime.parse(data['created_at']),
      isCompleted: data['is_completed'] ?? false,
      status: _parseStatus(data['status'] ?? 'toDo'),
      communityId: data['community_id'],
      categoryId: data['category_id'],
      priority: _parsePriority(data['priority'] ?? 'medium'),
      assignees: [], 
      isLocal: false,
    );
  }

  static Priority _parsePriority(String p) {
    switch (p.toLowerCase()) {
      case 'high': return Priority.high;
      case 'low': return Priority.low;
      default: return Priority.medium;
    }
  }

  static Status _parseStatus(String s) {
    switch (s) {
      case 'inProgress': return Status.inProgress;
      case 'done': return Status.done;
      default: return Status.toDo;
    }
  }
}
