// lib/features/sync/domain/sync_queue_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models/sync_mutation.dart';

abstract class ISyncRemoteRepository {
  Future<void> pushMutation(SyncMutation mutation);
}

abstract class ISyncLocalRepository {
  Future<void> saveLocal(String entityType, Map<String, dynamic> data);
  Future<void> rollback(String entityType, String entityId, Map<String, dynamic> snapshot);
  List<SyncMutation> getPendingMutations();
  Future<void> removeMutation(String id);
}

class SyncQueueManager extends ChangeNotifier {
  final ISyncLocalRepository localRepo;
  final ISyncRemoteRepository remoteRepo;
  final Connectivity connectivity;
  bool _isDraining = false;
  StreamSubscription? _connectivitySubscription;

  SyncQueueManager({
    required this.localRepo,
    required this.remoteRepo,
    required this.connectivity,
  }) {
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        drain();
      }
    });
  }

  int get pendingMutationsCount => localRepo.getPendingMutations().length;
  bool get isDraining => _isDraining;
  List<SyncMutation> get mutations => List.unmodifiable(localRepo.getPendingMutations());

  Future<void> mutate({
    required String entityId,
    required String entityType,
    required String action,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? rollbackSnapshot,
  }) async {
    // 1. Always apply optimistic update locally first
    await localRepo.saveLocal(entityType, payload);

    final mutation = SyncMutation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      entityId: entityId,
      entityType: entityType,
      action: action,
      payload: payload,
      rollbackSnapshot: rollbackSnapshot,
      queuedAt: DateTime.now(),
    );

    final conn = await connectivity.checkConnectivity();
    if (!conn.contains(ConnectivityResult.none)) {
      try {
        // 2. Direct online pass-through
        await remoteRepo.pushMutation(mutation);
        notifyListeners();
        return;
      } catch (_) {
        // Fall back into persistent queue if direct write fails
      }
    }

    // 3. Queue offline mutation
    final pending = localRepo.getPendingMutations();
    pending.add(mutation);
    notifyListeners();
  }

  Future<void> drain() async {
    if (_isDraining) return;
    _isDraining = true;
    notifyListeners();

    final pending = List<SyncMutation>.from(localRepo.getPendingMutations());
    for (final mutation in pending) {
      try {
        await remoteRepo.pushMutation(mutation);
        await localRepo.removeMutation(mutation.id);
      } catch (e) {
        if (mutation.retryCount >= 3 && mutation.rollbackSnapshot != null) {
          // Terminal rejection: execute rollback
          await localRepo.rollback(
            mutation.entityType,
            mutation.entityId,
            mutation.rollbackSnapshot!,
          );
          await localRepo.removeMutation(mutation.id);
        } else {
          mutation.retryCount++;
          break; // Stop draining until next retry/connectivity signal
        }
      }
    }
    _isDraining = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
