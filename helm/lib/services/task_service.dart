import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_service.dart';
import '../models/sync_model.dart';

class TaskService {
  final _supabase = Supabase.instance.client;
  final _syncService = SyncService();

  /// Create a new task with offline support.
  Future<void> createTask(Map<String, dynamic> taskData) async {
    final String id = taskData['id'];
    
    if (await _syncService.isOnline()) {
      try {
        await _supabase.from('tasks').upsert(taskData);
        return;
      } catch (e) {
        // Fallback to queue if server error
      }
    }
    
    await _syncService.addToQueue(
      id: id,
      action: SyncActionType.create,
      table: 'tasks',
      payload: taskData,
    );
  }

  /// Update a task with offline support.
  Future<void> updateTask(String id, Map<String, dynamic> updates) async {
    if (await _syncService.isOnline()) {
      try {
        await _supabase.from('tasks').update(updates).eq('id', id);
        return;
      } catch (e) {
        // Fallback to queue
      }
    }

    await _syncService.addToQueue(
      id: id,
      action: SyncActionType.update,
      table: 'tasks',
      payload: {'id': id, ...updates},
    );
  }

  /// Delete a task with offline support.
  Future<void> deleteTask(String id) async {
    if (await _syncService.isOnline()) {
      try {
        await _supabase.from('tasks').delete().eq('id', id);
        return;
      } catch (e) {
        // Fallback to queue
      }
    }

    await _syncService.addToQueue(
      id: id,
      action: SyncActionType.delete,
      table: 'tasks',
      payload: {'id': id},
    );
  }

  /// Read (Real-time Stream).
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
}
