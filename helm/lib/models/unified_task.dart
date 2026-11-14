import 'hive_models.dart' as hive_model;
import 'recurrence_rule.dart';

export 'recurrence_rule.dart';

enum Priority { low, medium, high }
enum Status { toDo, inProgress, done }

class UnifiedTask {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final DateTime? dueDate; // Explicit due date for calendar
  final bool isCompleted;
  final Status status;
  final String? communityId;
  final String? userId; // Creator ID
  final List<String> categoryIds;
  final Priority priority;
  final List<String> assignees;
  final bool isLocal; 
  final int order; 
  final List<Map<String, dynamic>> subtasks;
  final DateTime updatedAt;
  final bool isRecurring;
  final RecurrenceRule? recurrenceRule;
  final String? parentRecurringTaskId;
  final DateTime? originalDueDate;

  UnifiedTask({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    this.dueDate,
    required this.isCompleted,
    required this.status,
    this.communityId,
    this.userId,
    required this.categoryIds,
    required this.priority,
    required this.assignees,
    required this.isLocal,
    required this.order,
    required this.subtasks,
    required this.updatedAt,
    this.isRecurring = false,
    this.recurrenceRule,
    this.parentRecurringTaskId,
    this.originalDueDate,
  });

  factory UnifiedTask.fromHive(hive_model.Task task) {
    RecurrenceRule? rule;
    final bool isRec = task.isRecurring == true || task.recurrenceFrequency != null;
    if (isRec) {
      rule = RecurrenceRule(
        frequency: task.recurrenceFrequency ?? 'daily',
        interval: task.recurrenceInterval ?? 1,
        daysOfWeek: task.recurrenceDaysOfWeek,
        endDate: task.recurrenceEndDate,
      );
    }

    return UnifiedTask(
      id: task.id ?? '',
      title: task.title ?? 'Untitled',
      description: task.description ?? '',
      dateTime: task.dueAt ?? task.createdAt ?? DateTime.now(),
      dueDate: task.dueAt,
      isCompleted: task.isCompleted ?? false,
      status: parseStatus(task.status ?? 'toDo'),
      communityId: task.communityId,
      userId: task.userId,
      categoryIds: List.from(task.categoryIds ?? (task.categoryId != null ? [task.categoryId!] : [])),
      priority: parsePriority(task.priority ?? 'medium'),
      assignees: List.from(task.assignees ?? []),
      isLocal: task.communityId == null, 
      order: task.order ?? 0,
      subtasks: (task.subtasks ?? []).map((e) => Map<String, dynamic>.from(e)).toList(),
      updatedAt: task.updatedAt ?? task.createdAt ?? DateTime.now(),
      isRecurring: isRec,
      recurrenceRule: rule,
      parentRecurringTaskId: task.parentRecurringTaskId,
      originalDueDate: task.originalDueDate,
    );
  }

  factory UnifiedTask.fromSupabase(Map<String, dynamic> data) {
    final bool isRec = data['is_recurring'] == true || data['recurrence_frequency'] != null;
    RecurrenceRule? rule;
    if (isRec) {
      rule = RecurrenceRule.fromMap({
        'frequency': data['recurrence_frequency'] ?? 'daily',
        ...data,
      });
    }

    return UnifiedTask(
      id: data['id'].toString(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dateTime: data['due_at'] != null ? DateTime.parse(data['due_at']) : DateTime.parse(data['created_at']),
      dueDate: data['due_at'] != null ? DateTime.parse(data['due_at']) : null,
      isCompleted: data['is_completed'] ?? false,
      status: parseStatus(data['status'] ?? 'toDo'),
      communityId: data['community_id'],
      userId: data['user_id'],
      categoryIds: (data['category_ids'] as List?)?.cast<String>() ?? (data['category_id'] != null ? [data['category_id'].toString()] : []),
      priority: parsePriority(data['priority'] ?? 'medium'),
      assignees: (data['assignees'] as List?)?.cast<String>() ?? [], 
      isLocal: false,
      order: data['order'] ?? 0,
      subtasks: (data['subtasks'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
      updatedAt: data['updated_at'] != null ? DateTime.parse(data['updated_at']) : DateTime.parse(data['created_at']),
      isRecurring: isRec,
      recurrenceRule: rule,
      parentRecurringTaskId: data['parent_recurring_task_id']?.toString(),
      originalDueDate: data['original_due_date'] != null ? DateTime.tryParse(data['original_due_date'].toString()) : null,
    );
  }

  static Priority parsePriority(String? p) {
    if (p == null) return Priority.medium;
    switch (p.toLowerCase()) {
      case 'high': return Priority.high;
      case 'low': return Priority.low;
      default: return Priority.medium;
    }
  }

  static Status parseStatus(String? s) {
    if (s == null) return Status.toDo;
    switch (s.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
        return Status.inProgress;
      case 'done':
      case 'completed':
        return Status.done;
      default:
        return Status.toDo;
    }
  }
}
