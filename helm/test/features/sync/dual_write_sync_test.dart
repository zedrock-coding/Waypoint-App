// test/features/sync/dual_write_sync_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/sync/domain/sync_queue_manager.dart';
import 'package:waypoint/features/sync/presentation/widgets/sync_badge.dart';
import 'package:waypoint/features/task/domain/models/task.dart';

void main() {
  group('Dual-Write Synchronization Engine Tests', () {
    late FakeSupabaseClient fakeRemote;
    late FakeHiveStore localStore;

    setUp(() {
      fakeRemote = FakeSupabaseClient();
      localStore = FakeHiveStore();
    });

    test('1. Given online status, creating a task writes to local storage and invokes the remote client immediately without leaving items in sync_queue', () async {
      final syncManager = SyncQueueManager(
        remote: fakeRemote,
        local: localStore,
        isOnline: true,
      );

      final task = Task(
        id: 'task-online-1',
        title: 'Online Task',
        priority: TaskPriority.high,
        dueDate: DateTime.parse('2026-11-05T18:00:00+05:30'),
      );

      await syncManager.saveTask(task);

      // Local storage contains task
      expect(localStore.get('task-online-1'), isNotNull);
      // Remote invoked directly
      expect(fakeRemote.upsertedRows.any((r) => r['id'] == 'task-online-1'), isTrue);
      // Queue depth is 0 and status is synced
      expect(syncManager.queueDepth, 0);
      expect(syncManager.syncStatus, SyncStatus.synced);
    });

    test('2. Given offline status, creating a task writes locally and enqueues 1 mutation', () async {
      final syncManager = SyncQueueManager(
        remote: fakeRemote,
        local: localStore,
        isOnline: false,
      );

      final task = Task(
        id: 'task-offline-1',
        title: 'Offline Task',
        priority: TaskPriority.medium,
      );

      await syncManager.saveTask(task);

      // Local storage contains task
      expect(localStore.get('task-offline-1'), isNotNull);
      // Remote client not called
      expect(fakeRemote.upsertedRows.any((r) => r['id'] == 'task-offline-1'), isFalse);
      // 1 item queued, status pending
      expect(syncManager.queueDepth, 1);
      expect(syncManager.syncStatus, SyncStatus.pending);
    });

    test('3. Triggering drain() when connectivity returns flushes all mutations and reduces pending count to 0', () async {
      final syncManager = SyncQueueManager(
        remote: fakeRemote,
        local: localStore,
        isOnline: false,
      );

      final task1 = Task(id: 't-1', title: 'Task 1');
      final task2 = Task(id: 't-2', title: 'Task 2');

      await syncManager.saveTask(task1);
      await syncManager.saveTask(task2);
      expect(syncManager.queueDepth, 2);
      expect(syncManager.syncStatus, SyncStatus.pending);

      // Connectivity restored
      syncManager.isOnline = true;
      final syncedCount = await syncManager.drain();

      expect(syncedCount, 2);
      expect(fakeRemote.upsertedRows.length, 2);
      expect(syncManager.queueDepth, 0);
      expect(syncManager.syncStatus, SyncStatus.synced);
    });

    testWidgets('4. Verify the sync button callback directly invokes drain()', (tester) async {
      final syncManager = SyncQueueManager(
        remote: fakeRemote,
        local: localStore,
        isOnline: false,
      );

      final task = Task(id: 't-btn', title: 'Pending Task');
      await syncManager.saveTask(task);
      expect(syncManager.queueDepth, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                SyncBadge(queueManager: syncManager),
              ],
            ),
          ),
        ),
      );

      // Verify pending badge is displayed with count 1
      expect(find.byType(SyncBadge), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Tap badge to open bottom sheet
      await tester.tap(find.byType(SyncBadge));
      await tester.pumpAndSettle();

      // Verify modal bottom sheet displays pending task and Force Sync button
      expect(find.text('Pending Task'), findsOneWidget);
      final forceSyncButton = find.widgetWithText(ElevatedButton, 'Force Sync Now');
      expect(forceSyncButton, findsOneWidget);

      // Reconnect and tap Force Sync Now
      syncManager.isOnline = true;
      await tester.tap(forceSyncButton);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify drain was directly invoked and queue is emptied
      expect(syncManager.queueDepth, 0);
      expect(fakeRemote.upsertedRows.any((r) => r['id'] == 't-btn'), isTrue);
      expect(syncManager.syncStatus, SyncStatus.synced);
    });
  });
}

