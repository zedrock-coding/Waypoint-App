// test/features/sync/real_sync_dual_write_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/sync/domain/sync_queue_manager.dart';
import 'package:waypoint/features/task/domain/models/task.dart';

void main() {
  group('Real Sync Dual-Write Verification', () {
    test('Online write dispatches to remote and records locally without queuing', () async {
      final fakeRemote = FakeSupabaseClient();
      final localStore = FakeHiveStore();
      final syncManager = SyncQueueManager(remote: fakeRemote, local: localStore, isOnline: true);

      final task = Task(
        id: 'task-101',
        title: 'Assist Priyanshi',
        priority: TaskPriority.high,
        dueDate: DateTime.parse('2026-11-05T18:00:00+05:30'),
      );

      await syncManager.saveTask(task);

      expect(localStore.get('task-101'), isNotNull);
      expect(fakeRemote.upsertedRows.any((r) => r['id'] == 'task-101'), true);
      expect(syncManager.pendingQueueLength, 0);
    });
  });
}

