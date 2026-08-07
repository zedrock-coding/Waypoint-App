import 'package:supabase_flutter/supabase_flutter.dart';

class TaskService {
  final _supabase = Supabase.instance.client;

  /// Create a new task.
  Future<void> createTask({
    required String title,
    String? description,
    String? communityId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Auth Required');

    await _supabase.from('tasks').insert({
      'title': title,
      'description': description,
      'user_id': userId,
      'community_id': communityId,
      'is_completed': false,
    });
  }

  /// Read (Real-time Stream).
  /// Returns a stream of tasks, optionally filtered by communityId.
  Stream<List<Map<String, dynamic>>> getTasksStream({String? communityId}) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    final query = _supabase.from('tasks').stream(primaryKey: ['id']);

    if (communityId != null) {
      return query
          .eq('community_id', communityId)
          .order('created_at', ascending: false);
    } else {
      return query
          .eq('user_id', userId)
          .order('created_at', ascending: false);
    }
  }

  /// Update: Toggle completion status.
  Future<void> toggleTaskCompletion(String taskId, bool currentStatus) async {
    await _supabase
        .from('tasks')
        .update({'is_completed': !currentStatus})
        .eq('id', taskId);
  }

  /// Delete a task.
  Future<void> deleteTask(String taskId) async {
    await _supabase.from('tasks').delete().eq('id', taskId);
  }
}
