import 'package:hive/hive.dart';
import '../models/hive_models.dart';

class TaskRepository {
  final Box<Task> _taskBox = Hive.box<Task>('tasks');

  Future<List<Task>> getAllTasks() async {
    return _taskBox.values.toList();
  }

  Future<void> saveTask(Task task) async {
    await _taskBox.put(task.id, task);
  }

  Future<void> deleteTask(String id) async {
    await _taskBox.delete(id);
  }

  List<Task> getTasksForToday() {
    final now = DateTime.now();
    return _taskBox.values.where((t) {
      final date = t.dueAt ?? t.createdAt;
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).toList();
  }

  Stream<BoxEvent> watchTasks() {
    return _taskBox.watch();
  }
}
