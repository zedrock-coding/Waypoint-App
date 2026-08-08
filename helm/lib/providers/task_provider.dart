import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../models/hive_models.dart' as hive_model;
import '../models/unified_task.dart';
import '../models/event.dart' as isar_model;
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
    
    for (var event in events) {
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
          .where((t) => _selectedCategoryId == null || t.categoryId == _selectedCategoryId)
          .map((t) => UnifiedTask.fromHive(t))
          .toList();

      _personalTasks = allLocal;
      _personalTasks.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
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
              categoryId: d['category_id'],
              createdAt: DateTime.parse(d['created_at']),
              priority: d['priority'] ?? 'medium',
              status: d['status'] ?? 'toDo',
            );
            
            final existing = _taskBox.get(t.id);
            if (existing == null || existing.status != t.status || existing.title != t.title) {
              await _taskBox.put(t.id, t);
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
            );
            
            final existing = _categoryBox.get(c.id);
            if (existing == null || existing.name != c.name) {
              await _categoryBox.put(c.id, c);
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
              categoryId: d['category_id'],
              createdAt: DateTime.parse(d['created_at']),
              priority: d['priority'] ?? 'medium',
              status: d['status'] ?? 'toDo',
            );
            return UnifiedTask.fromHive(t);
          }).toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        });
  }

  Future<void> addTask({
    required String title,
    String? description,
    String? communityId,
    String? categoryId,
    Priority priority = Priority.medium,
    Status status = Status.toDo,
    bool isLocalOnly = false,
  }) async {
    final userId = isLocalOnly ? null : _supabase.auth.currentUser?.id;
    final id = const Uuid().v4();
    
    final localTask = hive_model.Task(
      id: id,
      title: title,
      description: description,
      isCompleted: status == Status.done,
      userId: userId,
      communityId: communityId,
      categoryId: categoryId,
      createdAt: DateTime.now(),
      priority: priority.name,
      status: _statusToString(status),
    );
    await _taskBox.put(id, localTask);

    if (!isLocalOnly && (communityId != null || userId != null)) {
      try {
        await _supabase.from('tasks').insert({
          'id': id,
          'title': title,
          'description': description,
          'community_id': communityId,
          'category_id': categoryId,
          'user_id': userId,
          'priority': priority.name,
          'status': _statusToString(status),
          'is_completed': status == Status.done,
        });
      } catch (e) {
        debugPrint('Supabase Sync Error: $e');
      }
    }
  }

  Future<void> addCategory(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    final id = const Uuid().v4();
    
    final localCategory = hive_model.Category(id: id, name: name);
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
    String? categoryId,
    Priority? priority,
    Status? status,
  }) async {
    final hiveTask = _taskBox.get(id);
    if (hiveTask == null) return;

    hiveTask.title = title;
    hiveTask.description = description;
    hiveTask.categoryId = categoryId;
    if (priority != null) hiveTask.priority = priority.name;
    if (status != null) {
      hiveTask.status = _statusToString(status);
      hiveTask.isCompleted = status == Status.done;
    }
    
    await hiveTask.save();

    final bool shouldSync = hiveTask.userId != null || hiveTask.communityId != null;
    if (shouldSync) {
      try {
        final Map<String, dynamic> updates = {
          'title': title,
          'description': description,
          'category_id': categoryId,
        };
        if (priority != null) updates['priority'] = priority.name;
        if (status != null) {
          updates['status'] = _statusToString(status);
          updates['is_completed'] = status == Status.done;
        }

        await _supabase.from('tasks').update(updates).eq('id', id);
      } catch (e) {
        debugPrint('Update Sync Error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> updateTaskStatus(UnifiedTask task, Status newStatus) async {
    final hiveTask = _taskBox.get(task.id);
    if (hiveTask != null) {
      hiveTask.status = _statusToString(newStatus);
      hiveTask.isCompleted = newStatus == Status.done;
      await hiveTask.save();
    }
    
    if (hiveTask?.userId != null || task.communityId != null) {
      try {
        await _supabase
            .from('tasks')
            .update({
              'status': _statusToString(newStatus),
              'is_completed': newStatus == Status.done,
            })
            .eq('id', task.id);
      } catch (e) {
        debugPrint('Sync Error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> toggleTask(UnifiedTask task) async {
    final newStatus = task.status == Status.done ? Status.toDo : Status.done;
    await updateTaskStatus(task, newStatus);
  }

  Future<void> deleteTask(String id) async {
    final hiveTask = _taskBox.get(id);
    final bool shouldSyncDelete = hiveTask?.userId != null || hiveTask?.communityId != null;

    await _taskBox.delete(id);
    
    if (shouldSyncDelete) {
      try {
        await _supabase.from('tasks').delete().eq('id', id);
      } catch (e) {
        debugPrint('Delete Sync Error: $e');
      }
    }
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
