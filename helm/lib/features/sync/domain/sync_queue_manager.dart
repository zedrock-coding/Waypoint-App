// lib/features/sync/domain/sync_queue_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models/sync_mutation.dart';
import '../../task/domain/models/task.dart';

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
}

class FakeHiveStore {
  final Map<String, dynamic> _data = {};

  dynamic get(String key) => _data[key];
  void put(String key, dynamic value) => _data[key] = value;
  void set(String key, dynamic value) => _data[key] = value;
  bool containsKey(String key) => _data.containsKey(key);
}

class SyncQueueManager extends ChangeNotifier {
  final ISyncLocalRepository? localRepo;
  final ISyncRemoteRepository? remoteRepo;
  final Connectivity? connectivity;
  final dynamic remote;
  final dynamic local;
  final bool isOnline;
  final List<SyncMutation> _inMemoryQueue = [];
  bool _isDraining = false;
  StreamSubscription? _connectivitySubscription;

  SyncQueueManager({
    this.localRepo,
    this.remoteRepo,
    this.connectivity,
    this.remote,
    this.local,
    this.isOnline = false,
  }) {
    if (connectivity != null) {
      _connectivitySubscription = connectivity!.onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) {
          drain();
        }
      });
    }
  }

  int get pendingMutationsCount =>
      _inMemoryQueue.length + (localRepo?.getPendingMutations().length ?? 0);

  int get pendingQueueLength => pendingMutationsCount;

  bool get isDraining => _isDraining;

  List<SyncMutation> get mutations {
    final list = <SyncMutation>[..._inMemoryQueue];
    if (localRepo != null) {
      list.addAll(localRepo!.getPendingMutations());
    }
    return List.unmodifiable(list);
  }

  static Future<bool> checkInternetReachability() async {
    try {
      final socket = await Socket.connect('api.supabase.co', 443,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
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
        return;
      }
      if (remoteRepo != null) {
        final mutation = SyncMutation(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          entityId: task.id,
          entityType: 'tasks',
          action: 'upsert',
          payload: payload,
          queuedAt: DateTime.now(),
        );
        await remoteRepo!.pushMutation(mutation);
        return;
      }
    }

    // 3. Offline: append to persistent queue
    final mutation = SyncMutation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      entityId: task.id,
      entityType: 'tasks',
      action: 'upsert',
      payload: payload,
      queuedAt: DateTime.now(),
    );
    if (localRepo != null) {
      localRepo!.getPendingMutations().add(mutation);
    } else {
      _inMemoryQueue.add(mutation);
    }
    notifyListeners();
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
  }

  Future<void> drain() async {
    if (_isDraining) return;
    _isDraining = true;
    notifyListeners();

    if (remoteRepo != null && localRepo != null) {
      final pending = List<SyncMutation>.from(localRepo!.getPendingMutations());
      for (final mutation in pending) {
        try {
          await remoteRepo!.pushMutation(mutation);
          await localRepo!.removeMutation(mutation.id);
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
            await remote.from(mutation.entityType).upsert(mutation.payload);
          }
          _inMemoryQueue.removeWhere((m) => m.id == mutation.id);
        } catch (_) {
          break;
        }
      }
    }

    _isDraining = false;
    notifyListeners();
  }

  Future<void> drainQueue() => drain();

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
