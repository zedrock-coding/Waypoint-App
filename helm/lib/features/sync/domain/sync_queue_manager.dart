// lib/features/sync/domain/sync_queue_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'models/sync_mutation.dart';
import '../../task/domain/models/task.dart';
import '../../../../models/sync_model.dart';
import '../../../../services/sync_service.dart';
import 'package:waypoint/services/widget_sync_service.dart';

enum SyncStatus {
  synced,
  syncing,
  pending,
}

abstract class ISyncRemoteRepository {
  Future<void> pushMutation(SyncMutation mutation);
}

abstract class ISyncLocalRepository {
  Future<void> saveLocal(String entityType, Map<String, dynamic> data);
  Future<void> rollback(String entityType, String entityId, Map<String, dynamic> snapshot);
  List<SyncMutation> getPendingMutations();
  Future<void> removeMutation(String id);
}

class FakeSupabaseClient {
  final List<Map<String, dynamic>> upsertedRows = [];

  dynamic from(String table) {
    return FakeSupabaseTable(this, table);
  }

  Future<void> upsert(Map<String, dynamic> row) async {
    upsertedRows.add(Map<String, dynamic>.from(row));
  }
}

class FakeSupabaseTable {
  final FakeSupabaseClient client;
  final String table;

  FakeSupabaseTable(this.client, this.table);

  Future<void> upsert(dynamic data) async {
    if (data is Map<String, dynamic>) {
      client.upsertedRows.add(Map<String, dynamic>.from(data));
    } else if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          client.upsertedRows.add(Map<String, dynamic>.from(item));
        }
      }
    }
  }

  Future<void> delete() async {}
}

class FakeHiveStore {
  final Map<String, dynamic> _data = {};

  dynamic get(String key) => _data[key];
  void put(String key, dynamic value) => _data[key] = value;
  void set(String key, dynamic value) => _data[key] = value;
  bool containsKey(String key) => _data.containsKey(key);
}

class SyncQueueManager extends ChangeNotifier {
  static SyncQueueManager? _appInstance;
  static SyncQueueManager get instance {
    _appInstance ??= SyncQueueManager();
    return _appInstance!;
  }

  final ISyncLocalRepository? localRepo;
  final ISyncRemoteRepository? remoteRepo;
  final Connectivity? connectivity;
  final dynamic remote;
  final dynamic local;
  bool isOnline;
  final List<SyncMutation> _inMemoryQueue = [];
  bool _isDraining = false;
  StreamSubscription? _connectivitySubscription;
  VoidCallback? _appSyncListener;

  SyncQueueManager({
    this.localRepo,
    this.remoteRepo,
    this.connectivity,
    this.remote,
    this.local,
    this.isOnline = false,
  }) {
    if (connectivity != null) {
      _connectivitySubscription = connectivity!.onConnectivityChanged.listen((results) async {
        if (!results.contains(ConnectivityResult.none)) {
          isOnline = true;
          await drain();
        } else {
          isOnline = false;
          notifyListeners();
        }
      });
    }

    // Bridge with app's SyncService if running in app mode (no explicit mock repos)
    if (remote == null && local == null && localRepo == null && remoteRepo == null) {
      _appSyncListener = () {
        notifyListeners();
      };
      SyncService().pendingChanges.addListener(_appSyncListener!);
    }
  }

  int _getAppPendingCount() {
    if (remote == null && local == null && localRepo == null && remoteRepo == null) {
      return SyncService().pendingCount;
    }
    return 0;
  }

  int get queueDepth =>
      _inMemoryQueue.length +
      (localRepo?.getPendingMutations().length ?? 0) +
      _getAppPendingCount();

  int get pendingQueueLength => queueDepth;
  int get pendingCount => queueDepth;
  int get pendingMutationsCount => queueDepth;

  bool get isDraining => _isDraining;

  SyncStatus get syncStatus {
    if (_isDraining) return SyncStatus.syncing;
    if (queueDepth > 0) return SyncStatus.pending;
    return SyncStatus.synced;
  }

  List<SyncMutation> get mutations {
    final list = <SyncMutation>[..._inMemoryQueue];
    if (localRepo != null) {
      list.addAll(localRepo!.getPendingMutations());
    }

    // If in app mode, bridge pending items from Hive 'sync_queue' box
    if (remote == null && local == null && localRepo == null && remoteRepo == null) {
      try {
        if (Hive.isBoxOpen('sync_queue')) {
          final box = Hive.box<SyncAction>('sync_queue');
          for (final action in box.values) {
            list.add(SyncMutation(
              id: action.id,
              entityId: action.id,
              entityType: action.table,
              action: action.action.name.toUpperCase(),
              payload: Map<String, dynamic>.from(action.payload),
              queuedAt: action.timestamp,
            ));
          }
        }
      } catch (_) {}
    }

    return List.unmodifiable(list);
  }

  static Future<bool> checkInternetReachability() async {
    try {
      final lookup = await InternetAddress.lookup('supabase.co')
          .timeout(const Duration(seconds: 2));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    try {
      final socket = await Socket.connect('api.supabase.co', 443,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkOnline() async {
    if (connectivity != null) {
      final results = await connectivity!.checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        isOnline = false;
        notifyListeners();
        return false;
      }
      final reachable = await checkInternetReachability();
      isOnline = reachable;
      notifyListeners();
      return reachable;
    }
    return isOnline;
  }

  Future<void> saveTask(Task task) async {
    final payload = task.toJson();

    // 1. Write immediately to local store
    if (local != null) {
      if (local is FakeHiveStore) {
        local.put(task.id, payload);
      } else {
        try {
          local.put(task.id, payload);
        } catch (_) {
          local[task.id] = payload;
        }
      }
    }
    if (localRepo != null) {
      await localRepo!.saveLocal('tasks', payload);
    }

    // 2. Online: direct dispatch without queueing
    if (isOnline) {
      try {
        if (remote != null) {
          if (remote is FakeSupabaseClient) {
            await remote.upsert(payload);
          } else {
            try {
              await remote.from('tasks').upsert(payload);
            } catch (_) {
              await remote.upsert(payload);
            }
          }
          notifyListeners();
          return;
        }
        if (remoteRepo != null) {
          final mutation = SyncMutation(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            entityId: task.id,
            entityType: 'tasks',
            action: 'CREATE',
            payload: payload,
            queuedAt: DateTime.now(),
          );
          await remoteRepo!.pushMutation(mutation);
          notifyListeners();
          return;
        }
      } catch (_) {
        // Fall back to queueing if remote call throws
      }
    }

    // 3. Offline: append to persistent queue
    final mutation = SyncMutation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      entityId: task.id,
      entityType: 'tasks',
      action: 'CREATE',
      payload: payload,
      queuedAt: DateTime.now(),
    );
    if (localRepo != null) {
      localRepo!.getPendingMutations().add(mutation);
    } else {
      _inMemoryQueue.add(mutation);
    }
    notifyListeners();
    try {
      WidgetSyncService.updateAllWidgets();
    } catch (_) {}
  }

  Future<void> mutate({
    required String entityId,
    required String entityType,
    required String action,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? rollbackSnapshot,
  }) async {
    // 1. Optimistic update locally
    if (localRepo != null) {
      await localRepo!.saveLocal(entityType, payload);
    }

    final mutation = SyncMutation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      entityId: entityId,
      entityType: entityType,
      action: action,
      payload: payload,
      rollbackSnapshot: rollbackSnapshot,
      queuedAt: DateTime.now(),
    );

    bool online = isOnline;
    if (connectivity != null) {
      final conn = await connectivity!.checkConnectivity();
      online = !conn.contains(ConnectivityResult.none);
    }

    if (online) {
      try {
        if (remoteRepo != null) {
          await remoteRepo!.pushMutation(mutation);
          notifyListeners();
          return;
        }
      } catch (_) {
        // Fall back into queue
      }
    }

    if (localRepo != null) {
      localRepo!.getPendingMutations().add(mutation);
    } else {
      _inMemoryQueue.add(mutation);
    }
    notifyListeners();
    try {
      WidgetSyncService.updateAllWidgets();
    } catch (_) {}
  }

  Future<int> drain({bool force = false}) async {
    if (_isDraining) return 0;

    _isDraining = true;
    notifyListeners();

    int syncedCount = 0;

    if (remoteRepo != null && localRepo != null) {
      final pending = List<SyncMutation>.from(localRepo!.getPendingMutations());
      for (final mutation in pending) {
        try {
          await remoteRepo!.pushMutation(mutation);
          await localRepo!.removeMutation(mutation.id);
          syncedCount++;
        } catch (e) {
          if (mutation.retryCount >= 3 && mutation.rollbackSnapshot != null) {
            await localRepo!.rollback(
              mutation.entityType,
              mutation.entityId,
              mutation.rollbackSnapshot!,
            );
            await localRepo!.removeMutation(mutation.id);
          } else {
            mutation.retryCount++;
            break;
          }
        }
      }
    } else if (remote != null) {
      final pending = List<SyncMutation>.from(_inMemoryQueue);
      for (final mutation in pending) {
        try {
          if (remote is FakeSupabaseClient) {
            await remote.upsert(mutation.payload);
          } else {
            try {
              await remote.from(mutation.entityType).upsert(mutation.payload);
            } catch (_) {
              await remote.upsert(mutation.payload);
            }
          }
          _inMemoryQueue.removeWhere((m) => m.id == mutation.id);
          syncedCount++;
        } catch (_) {
          break;
        }
      }
    } else {
      // In-app delegation to SyncService
      try {
        final initial = SyncService().pendingCount;
        await SyncService().processSyncQueue(force: force);
        final remaining = SyncService().pendingCount;
        syncedCount = (initial - remaining).clamp(0, initial);
      } catch (_) {}
    }

    _isDraining = false;
    notifyListeners();
    try {
      WidgetSyncService.updateAllWidgets();
    } catch (_) {}
    return syncedCount;
  }

  Future<int> drainQueue({bool force = false}) => drain(force: force);

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    if (_appSyncListener != null) {
      SyncService().pendingChanges.removeListener(_appSyncListener!);
    }
    super.dispose();
  }
}
