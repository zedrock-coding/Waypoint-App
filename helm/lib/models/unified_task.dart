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
  final List<String> categoryIds;
  final Priority priority;
  final List<String> assignees;
  final bool isLocal; 
  final int order; 

  UnifiedTask({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.isCompleted,
    required this.status,
    this.communityId,
    required this.categoryIds,
    required this.priority,
    required this.assignees,
    required this.isLocal,
    required this.order,
  });

  factory UnifiedTask.fromHive(hive_model.Task task) {
    return UnifiedTask(
      id: task.id ?? '',
      title: task.title ?? 'Untitled',
      description: task.description ?? '',
      dateTime: task.dueAt ?? task.createdAt ?? DateTime.now(),
      isCompleted: task.isCompleted ?? false,
      status: _parseStatus(task.status ?? 'toDo'),
      communityId: task.communityId,
      categoryIds: List.from(task.categoryIds ?? (task.categoryId != null ? [task.categoryId!] : [])),
      priority: _parsePriority(task.priority ?? 'medium'),
      assignees: List.from(task.assignees ?? []),
      isLocal: task.communityId == null, 
      order: task.order ?? 0,
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
      categoryIds: (data['category_ids'] as List?)?.cast<String>() ?? (data['category_id'] != null ? [data['category_id'].toString()] : []),
      priority: _parsePriority(data['priority'] ?? 'medium'),
      assignees: (data['assignees'] as List?)?.cast<String>() ?? [], 
      isLocal: false,
      order: data['order'] ?? 0,
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
