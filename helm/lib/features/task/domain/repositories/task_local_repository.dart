// lib/features/task/domain/repositories/task_local_repository.dart

import 'dart:async';
import 'package:hive/hive.dart';
import '../models/task.dart';
import 'package:waypoint/services/widget_sync_service.dart';

class TaskLocalRepository {
  final Box<dynamic>? tasksBox;
  final Box<dynamic>? subtasksBox;

  final Map<String, Map<String, dynamic>> _inMemoryTasks = {};
  final Map<String, Map<String, dynamic>> _inMemorySubtasks = {};

  TaskLocalRepository({
    this.tasksBox,
    this.subtasksBox,
  });

  Map<String, Map<String, dynamic>> get tasksStore => _inMemoryTasks;
  Map<String, Map<String, dynamic>> get subtasksStore => _inMemorySubtasks;

  Future<void> insertTask(Task task) async {
    final taskData = task.toJson();
    _inMemoryTasks[task.id] = taskData;

    if (tasksBox != null && tasksBox!.isOpen) {
      await tasksBox!.put(task.id, taskData);
    }

    // Explicitly write child subtask entities with foreign key task_id == parentTask.id
    for (int i = 0; i < task.subtasks.length; i++) {
      final subtask = task.subtasks[i];
      final subtaskId = 'sub_${task.id}_$i';
      final subtaskData = {
        'id': subtaskId,
        'task_id': task.id,
        'title': subtask.title,
        'due_date': subtask.dueDate?.toIso8601String(),
        'is_completed': subtask.isCompleted,
        'created_at': DateTime.now().toIso8601String(),
      };

      _inMemorySubtasks[subtaskId] = subtaskData;

      if (subtasksBox != null && subtasksBox!.isOpen) {
        await subtasksBox!.put(subtaskId, subtaskData);
      }
    }

    try {
      await WidgetSyncService.updateAllWidgets(tasks: [task]);
    } catch (_) {}
  }

  Future<Task?> getTask(String id) async {
    Map<String, dynamic>? data = _inMemoryTasks[id];
    if (data == null && tasksBox != null && tasksBox!.isOpen) {
      final raw = tasksBox!.get(id);
      if (raw != null) {
        data = Map<String, dynamic>.from(raw as Map);
      }
    }
    if (data == null) return null;

    final subtasksList = await getSubtasksForTask(id);
    return Task(
      id: data['id'] ?? id,
      title: data['title'] ?? '',
      description: data['description'],
      dueDate: data['due_date'] != null ? DateTime.tryParse(data['due_date']) : null,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name.toLowerCase() == (data!['priority'] ?? 'medium').toString().toLowerCase(),
        orElse: () => TaskPriority.medium,
      ),
      subtasks: subtasksList
          .map((s) => TaskSubtask(
                title: s['title'] ?? '',
                dueDate: s['due_date'] != null ? DateTime.tryParse(s['due_date']) : null,
                isCompleted: s['is_completed'] == true,
              ))
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> getSubtasksForTask(String taskId) async {
    final results = <Map<String, dynamic>>[];

    // Collect from in-memory
    for (final row in _inMemorySubtasks.values) {
      if (row['task_id'] == taskId) {
        results.add(Map<String, dynamic>.from(row));
      }
    }

    // Collect from Hive if available
    if (subtasksBox != null && subtasksBox!.isOpen) {
      for (final raw in subtasksBox!.values) {
        if (raw is Map && raw['task_id'] == taskId) {
          final mapped = Map<String, dynamic>.from(raw);
          if (!results.any((r) => r['id'] == mapped['id'])) {
            results.add(mapped);
          }
        }
      }
    }

    return results;
  }
}

