import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/sync/domain/sync_queue_manager.dart';
import 'package:waypoint/features/sync/presentation/widgets/sync_badge.dart';
import 'package:waypoint/features/task/domain/models/task.dart';

void main() {
  testWidgets('SyncBadge displays visible sync icon when all changes are synced', (tester) async {
    final fakeRemote = FakeSupabaseClient();
    final localStore = FakeHiveStore();
    final syncManager = SyncQueueManager(
      remote: fakeRemote,
      local: localStore,
      isOnline: true,
    );

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

    // Verify sync icon is visible
    expect(find.byType(SyncBadge), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(find.byTooltip('All changes synced'), findsOneWidget);
  });

  testWidgets('SyncBadge displays visible sync icon with amber badge when pending mutations exist', (tester) async {
    final fakeRemote = FakeSupabaseClient();
    final localStore = FakeHiveStore();
    final syncManager = SyncQueueManager(
      remote: fakeRemote,
      local: localStore,
      isOnline: false,
    );

    await syncManager.saveTask(Task(id: 'task-1', title: 'Task 1'));
    await syncManager.saveTask(Task(id: 'task-2', title: 'Task 2'));
    expect(syncManager.queueDepth, 2);

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

    expect(find.byType(SyncBadge), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byTooltip('2 pending sync changes'), findsOneWidget);
  });
}

