// lib/features/widgets/services/widget_sync_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:waypoint/features/task/domain/models/task.dart';
import 'package:waypoint/models/hive_models.dart' as hive_model;

class WidgetSyncService {
  static final Map<String, String> latestPayloads = {};

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _dayShortNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String formatDueTime(DateTime? date) {
    if (date == null) return '';
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int getPriorityWeight(dynamic priority) {
    if (priority == null) return 2;
    if (priority is TaskPriority) {
      switch (priority) {
        case TaskPriority.urgent:
          return 0;
        case TaskPriority.high:
          return 1;
        case TaskPriority.medium:
          return 2;
        case TaskPriority.low:
          return 3;
      }
    }
    final str = priority.toString().toLowerCase();
    if (str.contains('urgent') || str.contains('critical')) return 0;
    if (str.contains('high')) return 1;
    if (str.contains('low')) return 3;
    return 2; // Medium
  }

  static String getPriorityString(dynamic priority) {
    if (priority is TaskPriority) {
      return priority.name;
    }
    final str = priority?.toString().toLowerCase() ?? 'medium';
    if (str.contains('urgent') || str.contains('critical')) return 'urgent';
    if (str.contains('high')) return 'high';
    if (str.contains('low')) return 'low';
    return 'medium';
  }

  static Map<String, dynamic> normalizeTask(dynamic raw) {
    String id = '';
    String title = '';
    String? description;
    DateTime? dueDate;
    dynamic priority = 'medium';
    bool isCompleted = false;
    String subtaskProgress = '';
    int totalSubtasks = 0;
    int completedSubtasks = 0;

    if (raw is Task) {
      id = raw.id;
      title = raw.title;
      description = raw.description;
      dueDate = raw.dueDate;
      priority = raw.priority;
      totalSubtasks = raw.subtasks.length;
      completedSubtasks = raw.subtasks.where((s) => s.isCompleted).length;
      if (totalSubtasks > 0) {
        subtaskProgress = '$completedSubtasks/$totalSubtasks';
      }
    } else if (raw is hive_model.Task) {
      id = raw.id ?? '';
      title = raw.title ?? '';
      description = raw.description;
      dueDate = raw.dueAt ?? raw.createdAt;
      priority = raw.priority ?? 'medium';
      isCompleted = raw.isCompleted ?? (raw.status == 'done');
      final subs = raw.subtasks ?? [];
      totalSubtasks = subs.length;
      for (final s in subs) {
        if (s['is_completed'] == true || s['completed'] == true) {
          completedSubtasks++;
        }
      }
      if (totalSubtasks > 0) {
        subtaskProgress = '$completedSubtasks/$totalSubtasks';
      }
    } else if (raw is Map) {
      id = (raw['id'] ?? '').toString();
      title = (raw['title'] ?? '').toString();
      description = raw['description']?.toString();
      if (raw['due_date'] != null) {
        dueDate = DateTime.tryParse(raw['due_date'].toString());
      } else if (raw['dueAt'] != null) {
        dueDate = DateTime.tryParse(raw['dueAt'].toString());
      } else if (raw['dueDate'] != null) {
        dueDate = raw['dueDate'] is DateTime ? raw['dueDate'] as DateTime : DateTime.tryParse(raw['dueDate'].toString());
      }
      priority = raw['priority'] ?? 'medium';
      isCompleted = raw['is_completed'] == true || raw['status'] == 'done';
      final subs = raw['subtasks'] as List? ?? [];
      totalSubtasks = subs.length;
      for (final s in subs) {
        if (s is Map && (s['is_completed'] == true || s['completed'] == true)) {
          completedSubtasks++;
        }
      }
      if (totalSubtasks > 0) {
        subtaskProgress = '$completedSubtasks/$totalSubtasks';
      }
    }

    final pWeight = getPriorityWeight(priority);
    final pString = getPriorityString(priority);
    final dueTime = formatDueTime(dueDate);

    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'due_time': dueTime,
      'priority': pString,
      'priority_weight': pWeight,
      'is_completed': isCompleted,
      'subtask_progress': subtaskProgress,
      'total_subtasks': totalSubtasks,
      'completed_subtasks': completedSubtasks,
    };
  }

  static Map<String, List<Map<String, dynamic>>> groupTasksByDay(List<dynamic> tasks) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final raw in tasks) {
      final normalized = normalizeTask(raw);
      final dueDateStr = normalized['due_date'] as String?;
      String dateKey;
      if (dueDateStr != null && dueDateStr.isNotEmpty) {
        final parsed = DateTime.tryParse(dueDateStr);
        if (parsed != null) {
          dateKey = formatDateKey(parsed);
        } else {
          dateKey = formatDateKey(DateTime.now());
        }
      } else {
        dateKey = formatDateKey(DateTime.now());
      }

      grouped.putIfAbsent(dateKey, () => []).add(normalized);
    }

    return grouped;
  }

  static List<Map<String, dynamic>> sortTasksByPriority(List<dynamic> tasks) {
    final list = tasks.map((t) => normalizeTask(t)).toList();
    list.sort((a, b) => (a['priority_weight'] as int).compareTo(b['priority_weight'] as int));
    return list;
  }

  static Map<String, dynamic> generateMonthPayload(List<dynamic> tasks, {DateTime? anchor}) {
    final now = anchor ?? DateTime.now();
    final monthName = _monthNames[now.month - 1];
    final monthTitle = '$monthName ${now.year}';
    final grouped = groupTasksByDay(tasks);

    final pendingDays = <String>[];
    for (final entry in grouped.entries) {
      final hasPending = entry.value.any((t) => t['is_completed'] != true);
      if (hasPending) {
        pendingDays.add(entry.key);
      }
    }

    return {
      'month_title': monthTitle,
      'year': now.year,
      'month': now.month,
      'days': grouped,
      'pending_days': pendingDays,
    };
  }

  static Map<String, dynamic> generateWeekPayload(List<dynamic> tasks, {DateTime? anchor}) {
    final now = anchor ?? DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final grouped = groupTasksByDay(tasks);

    final daysList = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final dateKey = formatDateKey(day);
      final dayTasks = grouped[dateKey] ?? [];
      final pendingCount = dayTasks.where((t) => t['is_completed'] != true).length;
      final dayName = _dayShortNames[day.weekday - 1];

      daysList.add({
        'date': dateKey,
        'day_name': dayName,
        'day_number': day.day,
        'task_count': dayTasks.length,
        'pending_count': pendingCount,
        'tasks': dayTasks,
      });
    }

    return {
      'week_start': formatDateKey(monday),
      'days': daysList,
    };
  }

  static Map<String, dynamic> generateDayPayload(List<dynamic> tasks, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);
    final grouped = groupTasksByDay(tasks);
    final dayTasks = List<Map<String, dynamic>>.from(grouped[dateKey] ?? []);

    dayTasks.sort((a, b) => (a['priority_weight'] as int).compareTo(b['priority_weight'] as int));

    return {
      'date': dateKey,
      'tasks': dayTasks,
    };
  }

  static Future<void> updateAllWidgets({
    List<dynamic>? tasks,
    DateTime? anchor,
  }) async {
    List<dynamic> effectiveTasks = tasks ?? [];
    if (effectiveTasks.isEmpty) {
      if (Hive.isBoxOpen('tasks')) {
        final box = Hive.box<hive_model.Task>('tasks');
        effectiveTasks = box.values.toList();
      }
    }

    final now = anchor ?? DateTime.now();
    final monthPayload = generateMonthPayload(effectiveTasks, anchor: now);
    final weekPayload = generateWeekPayload(effectiveTasks, anchor: now);
    final dayPayload = generateDayPayload(effectiveTasks, date: now);

    final monthJson = jsonEncode(monthPayload);
    final weekJson = jsonEncode(weekPayload);
    final dayJson = jsonEncode(dayPayload);

    latestPayloads['waypoint_month_payload'] = monthJson;
    latestPayloads['waypoint_week_payload'] = weekJson;
    latestPayloads['waypoint_day_payload'] = dayJson;

    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/widget_month.json').writeAsString(monthJson);
      await File('${dir.path}/widget_week.json').writeAsString(weekJson);
      await File('${dir.path}/widget_day.json').writeAsString(dayJson);
    } catch (_) {
      // Ignored in environments without path_provider
    }

    try {
      await HomeWidget.saveWidgetData<String>('waypoint_month_payload', monthJson);
      await HomeWidget.saveWidgetData<String>('waypoint_week_payload', weekJson);
      await HomeWidget.saveWidgetData<String>('waypoint_day_payload', dayJson);

      await HomeWidget.updateWidget(androidName: 'WaypointMonthWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'WaypointWeekWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'WaypointDayWidgetProvider');
    } catch (e) {
      debugPrint('HomeWidget invocation failed: $e');
    }
  }
}
