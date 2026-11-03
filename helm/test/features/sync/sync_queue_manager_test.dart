// test/features/sync/sync_queue_manager_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/sync/domain/sync_queue_manager.dart';
import 'package:waypoint/features/sync/domain/models/sync_mutation.dart';

void main() {
  group('SyncQueueManager Rollback Tests', () {
    late MockLocalRepository localRepo;
    late MockRemoteRepository remoteRepo;
    late SyncQueueManager queueManager;

    setUp(() {
      localRepo = MockLocalRepository();
      remoteRepo = MockRemoteRepository();
      queueManager = SyncQueueManager(localRepo: localRepo, remoteRepo: remoteRepo);
    });

    test('Optimistic mutation rolls back locally on terminal server error', () async {
      final originalTask = {'id': 'task_1', 'title': 'Original Title'};
      localRepo.seed('task_1', originalTask);

      // Perform optimistic update
      final mutation = SyncMutation(
        id: 'mut_1',
        entityId: 'task_1',
        entityType: 'task',
        action: 'UPDATE',
        payload: {'title': 'Updated Title'},
        rollbackSnapshot: originalTask,
        queuedAt: DateTime.now(),
      );

      queueManager.enqueue(mutation);
      localRepo.apply(mutation.payload);
      expect(localRepo.get('task_1')['title'], 'Updated Title');

      // Simulate network 400 Bad Request
      remoteRepo.simulateTerminalFailure();

      await queueManager.drain();

      // Local repository must roll back to original snapshot
      expect(localRepo.get('task_1')['title'], 'Original Title');
      expect(queueManager.pendingMutationsCount, 0);
    });
  });
}

