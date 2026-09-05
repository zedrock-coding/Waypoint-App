import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../models/hive_models.dart' as hive_model;
import '../models/unified_task.dart';
import '../models/event.dart' as isar_model;
import '../models/sync_model.dart';
import '../services/sync_service.dart';
import 'package:uuid/uuid.dart';

class TaskProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _taskBox = Hive.box<hive_model.Task>('tasks');
  final _categoryBox = Hive.box<hive_model.Category>('categories');
  final Isar? isar;
  
  String? _selectedCategoryId;
  String? _activeCommunityId;

  List<UnifiedTask> _personalTasks = [];
  List<UnifiedTask> get personalTasks => _personalTasks;

  StreamSubscription? _supabaseSub;
  StreamSubscription? _categorySub;
  StreamSubscription? _hiveSub;

  TaskProvider({this.isar}) {
    _init();
  }

  String? get selectedCategoryId => _selectedCategoryId;
  String? get activeCommunityId => _activeCommunityId;

  void selectCategory(String? id) {
    _selectedCategoryId = id;
    _refreshPersonalTasks();
    notifyListeners();
  }

  void selectCommunity(String? id) {
    _activeCommunityId = id;
    notifyListeners();
  }

  void _init() {
    _refreshPersonalTasks();
    _hiveSub = _taskBox.watch().listen((_) => _refreshPersonalTasks());
    
    _setupSupabaseSync();
    _setupCategorySync();

    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
        _setupSupabaseSync();
        _setupCategorySync();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _supabaseSub?.cancel();
        _categorySub?.cancel();
        _refreshPersonalTasks();
      }
    });

    if (isar != null) {
      _migrateFromIsar();
    }
  }

  Future<void> _migrateFromIsar() async {
    if (isar == null) return;
    
    final events = await isar!.collection<isar_model.Event>().where().findAll();
    if (events.isEmpty) return;

    debugPrint('TaskProvider: Migrating ${events.length} tasks from Isar to Hive...');
    
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      final id = const Uuid().v4();
      final task = hive_model.Task(
        id: id,
        title: event.title,
        description: event.description,
        isCompleted: event.status == isar_model.Status.done,
        userId: _supabase.auth.currentUser?.id,
        createdAt: event.dateTime,
        priority: event.priority.name,
        status: _isarStatusToString(event.status),
        order: i,
        assignees: List.from(event.assignees),
        categoryIds: [], 
        subtasks: [],
      );
      
      await _taskBox.put(id, task);
      
      if (task.userId != null) {
        try {
          await _supabase.from('tasks').insert({
            'id': id,
            'title': task.title,
            'description': task.description,
            'user_id': task.userId,
            'priority': task.priority,
            'status': task.status,
            'is_completed': task.isCompleted,
            'created_at': task.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'order': i,
            'assignees': task.assignees,
            'subtasks': [],
          });
        } catch (e) {
          debugPrint('Migration Sync Error: $e');
        }
      }
    }

    await isar!.writeTxn(() => isar!.collection<isar_model.Event>().clear());
    debugPrint('TaskProvider: Migration Complete.');
  }

  String _isarStatusToString(isar_model.Status s) {
    switch (s) {
      case isar_model.Status.inProgress: return 'inProgress';
      case isar_model.Status.done: return 'done';
      default: return 'toDo';
    }
  }

  Future<void> _refreshPersonalTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      final allLocal = _taskBox.values
          .where((t) => t.communityId == null)
          .where((t) => t.userId == null || (userId != null && t.userId == userId)) 
          .where((t) {
            if (_selectedCategoryId == null) return true;
            final ids = t.categoryIds ?? (t.categoryId != null ? [t.categoryId!] : []);
            return ids.contains(_selectedCategoryId);
          })
          .map((t) => UnifiedTask.fromHive(t))
          .toList();

      allLocal.sort((a, b) {
        int cmp = a.order.compareTo(b.order);
        if (cmp != 0) return cmp;
        return b.dateTime.compareTo(a.dateTime);
      });

      _personalTasks = allLocal;
      notifyListeners();
    } catch (e) {
      debugPrint('TaskProvider Error: $e');
    }
  }

  void _setupSupabaseSync() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabaseSub?.cancel();
    _supabaseSub = _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .listen((data) async {
          for (var d in data) {
            final t = hive_model.Task(
              id: d['id'].toString(),
              title: d['title'] ?? 'Untitled',
              description: d['description'],
              isCompleted: d['is_completed'] ?? false,
              userId: d['user_id'],
              communityId: d['community_id'],
              categoryIds: (d['category_ids'] as List?)?.cast<String>() ?? (d['category_id'] != null ? [d['category_id'].toString()] : []),
              createdAt: DateTime.parse(d['created_at']),
              priority: d['priority'] ?? 'medium',
              status: d['status'] ?? 'toDo',
              order: d['order'] ?? 0,
              assignees: (d['assignees'] as List?)?.cast<String>() ?? [],
              subtasks: (d['subtasks'] as List?)?.map((e) => Map<dynamic, dynamic>.from(e)).toList() ?? [],
            );
            
            final existing = _taskBox.get(t.id);
            if (existing == null || existing.status != t.status || existing.title != t.title || existing.order != t.order) {
              await _taskBox.put(t.id!, t);
            }
          }
        });
  }

  void _setupCategorySync() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _categorySub?.cancel();
    _categorySub = _supabase
        .from('categories')
        .stream(primaryKey: ['id'])
        .listen((data) async {
          for (var d in data) {
            final c = hive_model.Category(
              id: d['id'].toString(),
              name: d['name'],
              userId: d['user_id'],
            );
            
            final existing = _categoryBox.get(c.id);
            if (existing == null || existing.name != c.name) {
              await _categoryBox.put(c.id!, c);
            }
          }
        });
  }

  Stream<List<UnifiedTask>> streamCommunityTasks(String communityId) {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('community_id', communityId)
        .map((data) {
          return data.map((d) {
            final t = hive_model.Task(
              id: d['id'].toString(),
              title: d['title'] ?? 'Untitled',
              description: d['description'],
              isCompleted: d['is_completed'] ?? false,
              userId: d['user_id'],
              communityId: d['community_id'],
              categoryIds: (d['category_ids'] as List?)?.cast<String>() ?? (d['category_id'] != null ? [d['category_id'].toString()] : []),
              createdAt: DateTime.parse(d['created_at']),
              priority: d['priority'] ?? 'medium',
              status: d['status'] ?? 'toDo',
              order: d['order'] ?? 0,
              assignees: (d['assignees'] as List?)?.cast<String>() ?? [],
              subtasks: (d['subtasks'] as List?)?.map((e) => Map<dynamic, dynamic>.from(e)).toList() ?? [],
            );
            return UnifiedTask.fromHive(t);
          }).toList()..sort((a, b) => a.order.compareTo(b.order));
        });
  }

  Future<void> addTask({
    required String title,
    String? description,
    String? communityId,
    List<String> categoryIds = const [],
    List<String> assignees = const [],
    List<Map<String, dynamic>> subtasks = const [],
    Priority priority = Priority.medium,
    Status status = Status.toDo,
    bool isLocalOnly = false,
    DateTime? dueAt,
  }) async {
    final userId = isLocalOnly ? null : _supabase.auth.currentUser?.id;
    final id = const Uuid().v4();
    
    final int newOrder = _personalTasks.isEmpty ? 0 : _personalTasks.first.order - 1;

    final localTask = hive_model.Task(
      id: id,
      title: title,
      description: description,
      isCompleted: status == Status.done,
      userId: userId,
      communityId: communityId,
      categoryIds: categoryIds,
      assignees: assignees,
      subtasks: subtasks.map((e) => Map<dynamic, dynamic>.from(e)).toList(),
      createdAt: DateTime.now(),
      dueAt: dueAt,
      priority: priority.name,
      status: _statusToString(status),
      order: newOrder,
    );
    await _taskBox.put(id, localTask);

    if (!isLocalOnly && (communityId != null || userId != null)) {
      final Map<String, dynamic> taskData = {
        'id': id,
        'title': title,
        'description': description,
        'community_id': communityId,
        'category_ids': categoryIds,
        'assignees': assignees,
        'subtasks': subtasks,
        'user_id': userId,
        'priority': priority.name,
        'status': _statusToString(status),
        'is_completed': status == Status.done,
        'order': newOrder,
        'due_at': dueAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (await SyncService().isOnline()) {
        try {
          await _supabase.from('tasks').upsert(taskData);
        } catch (e) {
          debugPrint('Supabase Sync Error, adding to queue: $e');
          await SyncService().addToQueue(id: id, action: SyncActionType.create, table: 'tasks', payload: taskData);
        }
      } else {
        await SyncService().addToQueue(id: id, action: SyncActionType.create, table: 'tasks', payload: taskData);
      }
    }
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    
    final List<UnifiedTask> updatedList = List.from(_personalTasks);
    final task = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, task);

    for (int i = 0; i < updatedList.length; i++) {
      final t = updatedList[i];
      final hiveTask = _taskBox.get(t.id);
      if (hiveTask != null && hiveTask.order != i) {
        hiveTask.order = i;
        await hiveTask.save();

        if (hiveTask.userId != null || hiveTask.communityId != null) {
          unawaited(_supabase.from('tasks').update({'order': i}).eq('id', t.id));
        }
      }
    }
    
    _personalTasks = updatedList;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    final id = const Uuid().v4();
    
    final localCategory = hive_model.Category(id: id, name: name, userId: userId);
    await _categoryBox.put(id, localCategory);

    if (userId != null) {
      try {
        await _supabase.from('categories').insert({
          'id': id,
          'name': name,
          'user_id': userId,
        });
      } catch (e) {
        debugPrint('Category Sync Error: $e');
      }
    }
  }

  Future<void> deleteCategory(String id) async {
    final cat = _categoryBox.get(id);
    if (cat != null && cat.name == 'General') return;

    await _categoryBox.delete(id);
    
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (e) {
      debugPrint('Category Delete Sync Error: $e');
    }
  }

  Future<void> updateTask({
    required String id,
    required String title,
    String? description,
    List<String> categoryIds = const [],
    List<String> assignees = const [],
    List<Map<String, dynamic>> subtasks = const [],
    Priority? priority,
    Status? status,
  }) async {
    final hiveTask = _taskBox.get(id);
    if (hiveTask == null) return;

    hiveTask.title = title;
    hiveTask.description = description;
    hiveTask.categoryIds = categoryIds;
    hiveTask.assignees = assignees;
    hiveTask.subtasks = subtasks.map((e) => Map<dynamic, dynamic>.from(e)).toList();
    hiveTask.updatedAt = DateTime.now();

    if (priority != null) hiveTask.priority = priority.name;
    if (status != null) {
      hiveTask.status = _statusToString(status);
      hiveTask.isCompleted = status == Status.done;
    }
    
    await hiveTask.save();

    final bool shouldSync = hiveTask.userId != null || hiveTask.communityId != null;
    if (shouldSync) {
      final Map<String, dynamic> updates = {
        'id': id,
        'title': title,
        'description': description,
        'category_ids': categoryIds,
        'assignees': assignees,
        'subtasks': subtasks,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (priority != null) updates['priority'] = priority.name;
      if (status != null) {
        updates['status'] = _statusToString(status);
        updates['is_completed'] = status == Status.done;
      }

      if (await SyncService().isOnline()) {
        try {
          await _supabase.from('tasks').upsert(updates);
        } catch (e) {
          debugPrint('Update Sync Error, adding to queue: $e');
          await SyncService().addToQueue(id: id, action: SyncActionType.update, table: 'tasks', payload: updates);
        }
      } else {
        await SyncService().addToQueue(id: id, action: SyncActionType.update, table: 'tasks', payload: updates);
      }
    }
    notifyListeners();
  }

  Future<void> toggleSubtask(String taskId, int index) async {
    final hiveTask = _taskBox.get(taskId);
    if (hiveTask == null || hiveTask.subtasks == null || index >= hiveTask.subtasks!.length) return;

    final List<Map<dynamic, dynamic>> subs = List.from(hiveTask.subtasks!);
    final Map<dynamic, dynamic> target = Map.from(subs[index]);
    target['is_completed'] = !(target['is_completed'] ?? false);
    subs[index] = target;
    
    hiveTask.subtasks = subs;
    hiveTask.updatedAt = DateTime.now();
    await hiveTask.save();

    final bool shouldSync = hiveTask.userId != null || hiveTask.communityId != null;
    if (shouldSync) {
      final updates = {
        'id': taskId,
        'subtasks': subs,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (await SyncService().isOnline()) {
        try {
          await _supabase.from('tasks').upsert(updates);
        } catch (e) {
          debugPrint('Subtask Sync Error, adding to queue: $e');
          await SyncService().addToQueue(id: taskId, action: SyncActionType.update, table: 'tasks', payload: updates);
        }
      } else {
        await SyncService().addToQueue(id: taskId, action: SyncActionType.update, table: 'tasks', payload: updates);
      }
    }
    notifyListeners();
  }

  // --- COMMENTING FEATURE ---

  Stream<List<Map<String, dynamic>>> streamTaskComments(String taskId) {
    return _supabase
        .from('task_comments')
        .stream(primaryKey: ['id'])
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
  }

  Future<void> addComment(String taskId, String text) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final String name = user.userMetadata?['full_name'] ?? 'User';

    try {
      await _supabase.from('task_comments').insert({
        'task_id': taskId,
        'user_id': user.id,
        'user_name': name,
        'comment_text': text,
      });
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  // --- GAMIFICATION FEATURE ---
  
  int get currentStreak {
    // Calculates a simple daily streak based on completed tasks
    final List<UnifiedTask> allCompleted = _taskBox.values
        .where((t) => (t.isCompleted ?? false) || t.status == 'done')
        .map((t) => UnifiedTask.fromHive(t))
        .toList();
        
    if (allCompleted.isEmpty) return 0;
    
    // Group by local Date (ignoring time)
    final Set<String> completedDates = {};
    for (var t in allCompleted) {
      final date = t.updatedAt; // The time it was marked done
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      completedDates.add(dateString);
    }
    
    int streak = 0;
    DateTime checkDate = DateTime.now();
    
    // Check if missed today, but did yesterday (streak is still active but 0 for today added yet)
    final todayStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
    
    if (!completedDates.contains(todayStr)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    while(true) {
      final str = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (completedDates.contains(str)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  // --- CALENDAR FEATURE ---
  
  List<UnifiedTask> get allTasksWithDueDates {
    // Aggregates both Personal and Community tasks that have a deadline
    final List<UnifiedTask> tasks = _taskBox.values
        .where((t) => t.dueAt != null)
        .map((t) => UnifiedTask.fromHive(t))
        .toList();
    
    // Sort by due date
    tasks.sort((a, b) => (a.dueDate ?? a.dateTime).compareTo(b.dueDate ?? b.dateTime));
    return tasks;
  }

  Future<void> updateTaskStatus(UnifiedTask task, Status newStatus) async {
    final hiveTask = _taskBox.get(task.id);
    if (hiveTask != null) {
      hiveTask.status = _statusToString(newStatus);
      hiveTask.isCompleted = newStatus == Status.done;
      hiveTask.updatedAt = DateTime.now();
      await hiveTask.save();
    }
    
    if (hiveTask?.userId != null || task.communityId != null) {
      final updates = {
        'id': task.id,
        'status': _statusToString(newStatus),
        'is_completed': newStatus == Status.done,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (await SyncService().isOnline()) {
        try {
          await _supabase.from('tasks').upsert(updates);
        } catch (e) {
          debugPrint('Sync Error, adding to queue: $e');
          await SyncService().addToQueue(id: task.id, action: SyncActionType.update, table: 'tasks', payload: updates);
        }
      } else {
        await SyncService().addToQueue(id: task.id, action: SyncActionType.update, table: 'tasks', payload: updates);
      }
    }
    notifyListeners();
  }

  Future<void> toggleTask(UnifiedTask task) async {
    final newStatus = task.status == Status.done ? Status.toDo : Status.done;
    await updateTaskStatus(task, newStatus);
  }

  hive_model.Task? _lastDeletedHiveTask;

  Future<void> deleteTask(String id) async {
    final hiveTask = _taskBox.get(id);
    if (hiveTask == null) return;

    _lastDeletedHiveTask = hive_model.Task(
      id: hiveTask.id,
      title: hiveTask.title,
      description: hiveTask.description,
      isCompleted: hiveTask.isCompleted,
      userId: hiveTask.userId,
      communityId: hiveTask.communityId,
      categoryId: hiveTask.categoryId,
      categoryIds: hiveTask.categoryIds,
      createdAt: hiveTask.createdAt ?? DateTime.now(),
      dueAt: hiveTask.dueAt,
      priority: hiveTask.priority,
      assignees: hiveTask.assignees,
      status: hiveTask.status,
      order: hiveTask.order,
      subtasks: hiveTask.subtasks,
      updatedAt: hiveTask.updatedAt,
    );

    final bool shouldSyncDelete = hiveTask.userId != null || hiveTask.communityId != null;

    await _taskBox.delete(id);
    
    if (shouldSyncDelete) {
      if (await SyncService().isOnline()) {
        try {
          await _supabase.from('tasks').delete().eq('id', id);
        } catch (e) {
          debugPrint('Delete Sync Error, adding to queue: $e');
          await SyncService().addToQueue(id: id, action: SyncActionType.delete, table: 'tasks', payload: {'id': id});
        }
      } else {
        await SyncService().addToQueue(id: id, action: SyncActionType.delete, table: 'tasks', payload: {'id': id});
      }
    }
    notifyListeners();
  }

  Future<void> undoDelete() async {
    if (_lastDeletedHiveTask == null) return;
    
    final task = _lastDeletedHiveTask!;
    await _taskBox.put(task.id!, task);

    final bool shouldSync = task.userId != null || task.communityId != null;
    if (shouldSync) {
      final taskData = {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'community_id': task.communityId,
        'category_ids': task.categoryIds,
        'assignees': task.assignees,
        'subtasks': task.subtasks,
        'user_id': task.userId,
        'priority': task.priority,
        'status': task.status,
        'is_completed': task.isCompleted,
        'created_at': task.createdAt?.toIso8601String(),
        'order': task.order,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (await SyncService().isOnline()) {
        try {
          await _supabase.from('tasks').upsert(taskData);
        } catch (e) {
          debugPrint('Undo Sync Error, adding to queue: $e');
          await SyncService().addToQueue(id: task.id!, action: SyncActionType.create, table: 'tasks', payload: taskData);
        }
      } else {
        await SyncService().addToQueue(id: task.id!, action: SyncActionType.create, table: 'tasks', payload: taskData);
      }
    }

    _lastDeletedHiveTask = null;
    notifyListeners();
  }

  String _statusToString(Status s) {
    switch (s) {
      case Status.inProgress: return 'inProgress';
      case Status.done: return 'done';
      default: return 'toDo';
    }
  }

  @override
  void dispose() {
    _supabaseSub?.cancel();
    _categorySub?.cancel();
    _hiveSub?.cancel();
    super.dispose();
  }
}
