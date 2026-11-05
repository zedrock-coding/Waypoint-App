// test/features/sync/sync_queue_manager_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/sync/domain/sync_queue_manager.dart';
import 'package:waypoint/features/sync/domain/models/sync_mutation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MockLocalRepo implements ISyncLocalRepository {
  final Map<String, Map<String, dynamic>> store = {};
  final List<SyncMutation> pendingQueue = [];

  @override
  Future<void> saveLocal(String entityType, Map<String, dynamic> data) async {
    store[data['id']] = Map.from(data);
  }

  @override
  Future<void> rollback(String entityType, String entityId, Map<String, dynamic> snapshot) async {
    store[entityId] = Map.from(snapshot);
  }

  @override
  List<SyncMutation> getPendingMutations() => pendingQueue;

  @override
  Future<void> removeMutation(String id) async {
    pendingQueue.removeWhere((m) => m.id == id);
  }
}

class MockRemoteRepo implements ISyncRemoteRepository {
  bool shouldFail = false;
  final List<SyncMutation> pushedMutations = [];

  @override
  Future<void> pushMutation(SyncMutation mutation) async {
    if (shouldFail) throw Exception("Network unreachable");
    pushedMutations.add(mutation);
  }
}

class MockConnectivity implements Connectivity {
  ConnectivityResult current = ConnectivityResult.wifi;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [current];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;
}

void main() {
  group('Dual-Write and Offline Sync Engine Tests', () {
    late MockLocalRepo localRepo;
    late MockRemoteRepo remoteRepo;
    late MockConnectivity mockConn;
    late SyncQueueManager manager;

    setUp(() {
      localRepo = MockLocalRepo();
      remoteRepo = MockRemoteRepo();
      mockConn = MockConnectivity();
      manager = SyncQueueManager(localRepo: localRepo, remoteRepo: remoteRepo, connectivity: mockConn);
    });

    test('Online mutation writes to local and remote simultaneously without queue delay', () async {
      mockConn.current = ConnectivityResult.wifi;

      await manager.mutate(
        entityId: 't1',
        entityType: 'task',
        action: 'CREATE',
        payload: {'id': 't1', 'title': 'Online Task'},
      );

      // Local write immediate
      expect(localRepo.store['t1']?['title'], 'Online Task');
      // Remote write immediate
      expect(remoteRepo.pushedMutations.length, 1);
      // Pending queue stays clean
      expect(localRepo.pendingQueue.isEmpty, true);
    });

    test('Offline mutation queues item, and drain synchronizes when network recovers', () async {
      mockConn.current = ConnectivityResult.none;

      await manager.mutate(
        entityId: 't2',
        entityType: 'task',
        action: 'CREATE',
        payload: {'id': 't2', 'title': 'Offline Task'},
      );

      expect(localRepo.store['t2']?['title'], 'Offline Task');
      expect(remoteRepo.pushedMutations.isEmpty, true);
      expect(localRepo.pendingQueue.length, 1);

      // Simulate network coming back online
      mockConn.current = ConnectivityResult.mobile;
      await manager.drain();

      expect(remoteRepo.pushedMutations.length, 1);
      expect(localRepo.pendingQueue.isEmpty, true);
    });

    test('Terminal failure rolls back local store', () async {
      mockConn.current = ConnectivityResult.none;
      final original = {'id': 't3', 'title': 'Original'};
      await localRepo.saveLocal('task', original);

      await manager.mutate(
        entityId: 't3',
        entityType: 'task',
        action: 'UPDATE',
        payload: {'id': 't3', 'title': 'Bad Update'},
        rollbackSnapshot: original,
      );

      expect(localRepo.store['t3']?['title'], 'Bad Update');

      remoteRepo.shouldFail = true;
      localRepo.pendingQueue.first.retryCount = 3; // Trigger terminal threshold

      await manager.drain();

      // Verified rollback to snapshot
      expect(localRepo.store['t3']?['title'], 'Original');
      expect(localRepo.pendingQueue.isEmpty, true);
    });
  });
}
