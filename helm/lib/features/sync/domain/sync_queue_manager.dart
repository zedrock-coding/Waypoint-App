// lib/features/sync/domain/sync_queue_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/sync_mutation.dart';

class TerminalSyncException implements Exception {
  final String message;
  const TerminalSyncException(this.message);
  @override
  String toString() => 'TerminalSyncException: $message';
}

abstract class ILocalRepository {
  void seed(String id, Map<String, dynamic> data);
  void apply(Map<String, dynamic> data);
  void rollback(String id, Map<String, dynamic>? snapshot);
  Map<String, dynamic> get(String id);
}

abstract class IRemoteRepository {
  Future<void> syncMutation(SyncMutation mutation);
  void simulateTerminalFailure();
}

class MockLocalRepository implements ILocalRepository {
  final Map<String, Map<String, dynamic>> _storage = {};

  @override
  void seed(String id, Map<String, dynamic> data) {
    _storage[id] = Map<String, dynamic>.from(data);
  }

  @override
  void apply(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? (_storage.keys.isNotEmpty ? _storage.keys.first : null);
    if (id != null) {
      final existing = _storage[id] ?? {};
      _storage[id] = {...existing, ...data};
    }
  }

  @override
  void rollback(String id, Map<String, dynamic>? snapshot) {
    if (snapshot != null) {
      _storage[id] = Map<String, dynamic>.from(snapshot);
    } else {
      _storage.remove(id);
    }
  }

  @override
  Map<String, dynamic> get(String id) => _storage[id] ?? {};
}

class MockRemoteRepository implements IRemoteRepository {
  bool _shouldFailTerminally = false;

  @override
  void simulateTerminalFailure() {
    _shouldFailTerminally = true;
  }

  @override
  Future<void> syncMutation(SyncMutation mutation) async {
    if (_shouldFailTerminally) {
      throw const TerminalSyncException('400 Bad Request');
    }
  }
}

class SyncQueueManager extends ChangeNotifier {
  final ILocalRepository localRepo;
  final IRemoteRepository remoteRepo;
  final List<SyncMutation> _queue = [];
  bool _isDraining = false;

  SyncQueueManager({
    required this.localRepo,
    required this.remoteRepo,
  });

  int get pendingMutationsCount => _queue.length;
  bool get isDraining => _isDraining;
  List<SyncMutation> get mutations => List.unmodifiable(_queue);

  void enqueue(SyncMutation mutation) {
    _queue.add(mutation);
    notifyListeners();
  }

  Future<void> drain() async {
    if (_isDraining || _queue.isEmpty) return;
    _isDraining = true;
    notifyListeners();

    final List<SyncMutation> processed = [];

    for (final mutation in List<SyncMutation>.from(_queue)) {
      try {
        await remoteRepo.syncMutation(mutation);
        processed.add(mutation);
      } on TerminalSyncException catch (e) {
        debugPrint('Terminal sync rejection: $e. Executing local rollback for ${mutation.entityId}');
        localRepo.rollback(mutation.entityId, mutation.rollbackSnapshot);
        processed.add(mutation);
      } catch (e) {
        mutation.retryCount++;
        debugPrint('Temporary sync error: $e. Retry count: ${mutation.retryCount}');
      }
    }

    _queue.removeWhere((m) => processed.contains(m));
    _isDraining = false;
    notifyListeners();
  }
}

