import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hive_models.dart' as hive_model;
import '../models/unified_task.dart';
import '../models/sync_model.dart';
import '../services/sync_service.dart';
import '../services/task_merge.dart';
import '../notification_service.dart';
import 'package:uuid/uuid.dart';

class TaskProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _taskBox = Hive.box<hive_model.Task>('tasks');
  final _categoryBox = Hive.box<hive_model.Category>('categories');

  String? _selectedCategoryId;
  String? _activeCommunityId;

  List<UnifiedTask> _personalTasks = [];
  List<UnifiedTask> get personalTasks => _personalTasks;

  StreamSubscription? _supabaseSub;
  StreamSubscription? _categorySub;
  StreamSubscription? _hiveSub;

  TaskProvider() {
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
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        // A new session means the old realtime subscriptions are dead; cached
        // streams would never emit again.
        _communityTaskStreams.clear();
        _commentStreams.clear();
        _setupSupabaseSync();
        _setupCategorySync();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _supabaseSub?.cancel();
        _categorySub?.cancel();
        _communityTaskStreams.clear();
        _commentStreams.clear();
        _refreshPersonalTasks();
      }
    });
  }

  Future<void> _refreshPersonalTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      final allLocal = _taskBox.values
          .where((t) => t.communityId == null)
          .where(
            (t) => t.userId == null || (userId != null && t.userId == userId),
          )
          .where((t) {
            if (_selectedCategoryId == null) return true;
            final ids =
                t.categoryIds ?? (t.categoryId != null ? [t.categoryId!] : []);
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
    _supabaseSub = _supabase.from('tasks').stream(primaryKey: ['id']).listen((
      data,
    ) async {
      final sync = SyncService();
      final remoteIds = <String>{};

      for (var d in data) {
        final id = d['id'].toString();
        remoteIds.add(id);

        final existing = _taskBox.get(id);

        // The stream returns every task this user can read, including other
        // people's community tasks. Those are served live by
        // streamCommunityTasks(); mirroring them into the personal box mixed
        // scopes for no benefit. Rows already mirrored (created here) keep
        // updating so the calendar and offline reads stay correct.
        if (d['community_id'] != null && existing == null) continue;

        final remote = _taskFromRow(d);
        if (!shouldApplyRemoteUpdate(
          localUpdatedAt: existing?.updatedAt,
          remoteUpdatedAt: remote.updatedAt,
          hasPendingWrite: sync.hasPending(id),
        )) {
          continue;
        }

        await _taskBox.put(id, remote);
      }

      // Deletes on another device never arrive as an event, so diff the
      // snapshot against the local mirror. Rows created offline and rows
      // with an unflushed write are excluded by the helper.
      final stale = localRowsMissingRemotely(
        localRows: _taskBox.values,
        remoteIds: remoteIds,
        hasPendingWrite: (task) => sync.hasPending(task.id!),
      );
      if (stale.isNotEmpty) {
        debugPrint(
          'TaskProvider: removing ${stale.length} task(s) deleted on another device',
        );
        await _taskBox.deleteAll(stale);
      }
    });
  }

  /// Maps a PostgREST row to the Hive entity, defensively.
  ///
  /// Realtime payloads are untyped JSON from another process; a null `created_at`
  /// or a string `order` used to throw inside the stream listener and kill the
  /// subscription for the rest of the session.
  hive_model.Task _taskFromRow(Map<String, dynamic> d) {
    final createdAt = DateTime.tryParse(d['created_at']?.toString() ?? '');
    final dueAt = DateTime.tryParse(d['due_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(d['updated_at']?.toString() ?? '');

    final rawCategories = d['category_ids'];
    final categoryIds = rawCategories is List
        ? rawCategories.map((e) => e.toString()).toList()
        : (d['category_id'] != null
              ? [d['category_id'].toString()]
              : <String>[]);

    final rawAssignees = d['assignees'];
    final assignees = rawAssignees is List
        ? rawAssignees.map((e) => e.toString()).toList()
        : <String>[];

    final rawSubtasks = d['subtasks'];
    final subtasks = rawSubtasks is List
        ? rawSubtasks
              .whereType<Map>()
              .map((e) => Map<dynamic, dynamic>.from(e))
              .toList()
        : <Map<dynamic, dynamic>>[];

    final title = d['title']?.toString().trim() ?? '';

    return hive_model.Task(
      id: d['id'].toString(),
      title: title.isEmpty ? 'Untitled' : title,
      description: d['description']?.toString(),
      isCompleted: d['is_completed'] == true,
      userId: d['user_id']?.toString(),
      communityId: d['community_id']?.toString(),
      categoryIds: categoryIds,
      createdAt: createdAt ?? DateTime.now(),
      dueAt: dueAt,
      priority: d['priority']?.toString() ?? 'medium',
      status: d['status']?.toString() ?? 'toDo',
      order: (d['order'] as num?)?.toInt() ?? 0,
      assignees: assignees,
      subtasks: subtasks,
      updatedAt: updatedAt,
    );
  }

  /// Community task streams, memoized per community.
  ///
  /// `StreamBuilder` used to receive a brand-new stream on every build, which
  /// tore down and re-established the realtime subscription on each frame — the
  /// likely cause of duplicated comment deliveries and pointless socket churn.
  final Map<String, Stream<List<UnifiedTask>>> _communityTaskStreams = {};

  Stream<List<UnifiedTask>> communityTasksStream(String communityId) {
    return _communityTaskStreams.putIfAbsent(communityId, () {
      return _supabase
          .from('tasks')
          .stream(primaryKey: ['id'])
          .eq('community_id', communityId)
          .map((data) {
            return data.map((d) => UnifiedTask.fromHive(_taskFromRow(d))).toList()
              ..sort((a, b) => a.order.compareTo(b.order));
          });
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

  /// The single write path for remote mutations.
  ///
  /// Every caller used to open-code "if online try upsert else enqueue", and
  /// reorder/category operations skipped the queue entirely — those changes were
  /// lost whenever the network happened to be down. One helper means one place
  /// where that can be wrong.
  ///
  /// Returns `true` when the write reached Supabase immediately, `false` when it
  /// was queued for a later flush.
  Future<bool> _mutate({
    required String table,
    required String id,
    required SyncActionType action,
    required Map<String, dynamic> payload,
  }) async {
    if (await SyncService().isOnline()) {
      try {
        if (action == SyncActionType.delete) {
          await _supabase.from(table).delete().eq('id', id);
        } else {
          await _supabase.from(table).upsert(payload);
        }
        return true;
      } catch (e) {
        debugPrint('Supabase $action failed for $table/$id, queueing: $e');
      }
    }
    await SyncService().addToQueue(
      id: id,
      action: action,
      table: table,
      payload: payload,
    );
    return false;
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

    final int newOrder = _personalTasks.isEmpty
        ? 0
        : _personalTasks.first.order - 1;

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

    if (dueAt != null && status != Status.done) {
      unawaited(
        NotificationService().scheduleTaskDueDateNotification(
          taskId: id,
          title: title,
          dueAt: dueAt,
        ),
      );
    }

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

      await _mutate(
        table: 'tasks',
        id: id,
        action: SyncActionType.create,
        payload: taskData,
      );
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
          await _mutate(
            table: 'tasks',
            id: t.id,
            action: SyncActionType.update,
            payload: {
              'id': t.id,
              'order': i,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
        }
      }
    }

    _personalTasks = updatedList;
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    final id = const Uuid().v4();

    final localCategory = hive_model.Category(
      id: id,
      name: name,
      userId: userId,
    );
    await _categoryBox.put(id, localCategory);

    if (userId != null) {
      await _mutate(
        table: 'categories',
        id: id,
        action: SyncActionType.create,
        payload: {'id': id, 'name': name, 'user_id': userId},
      );
    }
  }

  Future<void> deleteCategory(String id) async {
    final cat = _categoryBox.get(id);
    if (cat != null && cat.name == 'General') return;

    await _categoryBox.delete(id);

    // Local-only categories were never in Supabase; deleting remotely is still
    // harmless and keeps the offline path identical to the online one.
    await _mutate(
      table: 'categories',
      id: id,
      action: SyncActionType.delete,
      payload: {'id': id},
    );
  }

  Future<void> updateTask({
    required String id,
    required String title,
    String? description,
    DateTime? dueAt,
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
    hiveTask.dueAt = dueAt;
    hiveTask.categoryIds = categoryIds;
    hiveTask.assignees = assignees;
    hiveTask.subtasks = subtasks
        .map((e) => Map<dynamic, dynamic>.from(e))
        .toList();
    hiveTask.updatedAt = DateTime.now();

    if (priority != null) hiveTask.priority = priority.name;
    if (status != null) {
      hiveTask.status = _statusToString(status);
      hiveTask.isCompleted = status == Status.done;
    }

    await hiveTask.save();

    if (hiveTask.dueAt != null && hiveTask.status != 'done') {
      unawaited(
        NotificationService().scheduleTaskDueDateNotification(
          taskId: id,
          title: hiveTask.title ?? title,
          dueAt: hiveTask.dueAt!,
        ),
      );
    } else {
      unawaited(NotificationService().cancelTaskNotifications(id));
    }

    final bool shouldSync =
        hiveTask.userId != null || hiveTask.communityId != null;
    if (shouldSync) {
      final Map<String, dynamic> updates = {
        'id': id,
        'title': title,
        'description': description,
        'category_ids': categoryIds,
        'assignees': assignees,
        'subtasks': subtasks,
        'due_at': dueAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (priority != null) updates['priority'] = priority.name;
      if (status != null) {
        updates['status'] = _statusToString(status);
        updates['is_completed'] = status == Status.done;
      }

      await _mutate(
        table: 'tasks',
        id: id,
        action: SyncActionType.update,
        payload: updates,
      );
    }
    notifyListeners();
  }

  Future<void> toggleSubtask(String taskId, int index) async {
    final hiveTask = _taskBox.get(taskId);
    if (hiveTask == null ||
        hiveTask.subtasks == null ||
        index >= hiveTask.subtasks!.length) {
      return;
    }

    final List<Map<dynamic, dynamic>> subs = List.from(hiveTask.subtasks!);
    final Map<dynamic, dynamic> target = Map.from(subs[index]);
    target['is_completed'] = !(target['is_completed'] ?? false);
    subs[index] = target;

    hiveTask.subtasks = subs;
    hiveTask.updatedAt = DateTime.now();
    await hiveTask.save();

    final bool shouldSync =
        hiveTask.userId != null || hiveTask.communityId != null;
    if (shouldSync) {
      final updates = {
        'id': taskId,
        'subtasks': subs,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _mutate(
        table: 'tasks',
        id: taskId,
        action: SyncActionType.update,
        payload: updates,
      );
    }
    notifyListeners();
  }

  // --- COMMENTING FEATURE ---

  /// Comments stream, memoized per task for the same reason as community tasks:
  /// a new stream on every build re-subscribes and can deliver duplicates.
  final Map<String, Stream<List<Map<String, dynamic>>>> _commentStreams = {};

  Stream<List<Map<String, dynamic>>> streamTaskComments(String taskId) {
    return _commentStreams.putIfAbsent(taskId, () {
      return _supabase
          .from('task_comments')
          .stream(primaryKey: ['id'])
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
    });
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
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      completedDates.add(dateString);
    }

    int streak = 0;
    DateTime checkDate = DateTime.now();

    // Check if missed today, but did yesterday (streak is still active but 0 for today added yet)
    final todayStr =
        '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';

    if (!completedDates.contains(todayStr)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final str =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
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
    tasks.sort(
      (a, b) => (a.dueDate ?? a.dateTime).compareTo(b.dueDate ?? b.dateTime),
    );
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

    if (newStatus == Status.done) {
      unawaited(NotificationService().cancelTaskNotifications(task.id));
    } else if (task.dueDate != null) {
      unawaited(
        NotificationService().scheduleTaskDueDateNotification(
          taskId: task.id,
          title: task.title,
          dueAt: task.dueDate!,
        ),
      );
    }

    if (hiveTask?.userId != null || task.communityId != null) {
      final updates = {
        'id': task.id,
        'status': _statusToString(newStatus),
        'is_completed': newStatus == Status.done,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _mutate(
        table: 'tasks',
        id: task.id,
        action: SyncActionType.update,
        payload: updates,
      );
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

    if (hiveTask != null) {
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
    }

    // Enqueue the remote delete even when the local row is already gone. The
    // old early-return meant that deleting a task whose Hive mirror had been
    // dropped (e.g. by the remote-delete snapshot diff) silently left the
    // server row in place, and it came back on the next reconnect.
    final bool shouldSyncDelete =
        hiveTask == null ||
        hiveTask.userId != null ||
        hiveTask.communityId != null;

    if (hiveTask != null) {
      await _taskBox.delete(id);
      unawaited(NotificationService().cancelTaskNotifications(id));
    }

    if (shouldSyncDelete) {
      await _mutate(
        table: 'tasks',
        id: id,
        action: SyncActionType.delete,
        payload: {'id': id},
      );
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

      final bool written = await _mutate(
        table: 'tasks',
        id: task.id!,
        action: SyncActionType.create,
        payload: taskData,
      );
      // A queued delete must not survive the undo, or the next flush would
      // delete the row we just restored. addToQueue already merges a create
      // over a delete; a successful immediate write supersedes it outright.
      if (written) {
        await SyncService().removeFromQueue(table: 'tasks', id: task.id!);
      }
    }

    _lastDeletedHiveTask = null;
    notifyListeners();
  }

  String _statusToString(Status s) {
    switch (s) {
      case Status.inProgress:
        return 'inProgress';
      case Status.done:
        return 'done';
      default:
        return 'toDo';
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
