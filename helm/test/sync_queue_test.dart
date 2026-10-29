import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:helm/models/sync_model.dart';
import 'package:helm/services/sync_service.dart';

void main() {
  late Directory tempDir;
  late Box<SyncAction> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('helm_sync_queue_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SyncActionAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(SyncActionTypeAdapter());
    }
    box = await Hive.openBox<SyncAction>('sync_queue');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await box.clear();
  });

  group('addToQueue coalescing', () {
    test('create then delete cancels out', () async {
      final sync = SyncService();
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.create,
        table: 'tasks',
        payload: {'id': 'a', 'title': 'A'},
      );
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.delete,
        table: 'tasks',
        payload: {'id': 'a'},
      );

      expect(box.isEmpty, isTrue);
      expect(sync.hasPending('a'), isFalse);
    });

    test('create then update merges into a single create', () async {
      final sync = SyncService();
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.create,
        table: 'tasks',
        payload: {'id': 'a', 'title': 'A', 'status': 'toDo'},
      );
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.update,
        table: 'tasks',
        payload: {'id': 'a', 'status': 'done'},
      );

      expect(box.length, 1);
      final action = box.get(SyncService.queueKey('tasks', 'a'))!;
      expect(action.action, SyncActionType.create);
      expect(action.payload['title'], 'A');
      expect(action.payload['status'], 'done');
    });

    test('consecutive updates merge payloads', () async {
      final sync = SyncService();
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.update,
        table: 'tasks',
        payload: {'id': 'a', 'priority': 'high'},
      );
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.update,
        table: 'tasks',
        payload: {'id': 'a', 'order': 3},
      );

      expect(box.length, 1);
      final action = box.get(SyncService.queueKey('tasks', 'a'))!;
      expect(action.action, SyncActionType.update);
      expect(action.payload['priority'], 'high');
      expect(action.payload['order'], 3);
    });

    test('a queued delete swallows a later update', () async {
      final sync = SyncService();
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.delete,
        table: 'tasks',
        payload: {'id': 'a'},
      );
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.update,
        table: 'tasks',
        payload: {'id': 'a', 'title': 'renamed'},
      );

      expect(box.length, 1);
      expect(
        box.get(SyncService.queueKey('tasks', 'a'))!.action,
        SyncActionType.delete,
      );
    });

    test('same id in different tables stays two actions', () async {
      final sync = SyncService();
      await sync.addToQueue(
        id: 'x',
        action: SyncActionType.create,
        table: 'tasks',
        payload: {'id': 'x'},
      );
      await sync.addToQueue(
        id: 'x',
        action: SyncActionType.create,
        table: 'categories',
        payload: {'id': 'x'},
      );

      expect(box.length, 2);
      expect(sync.hasPending('x'), isTrue);
      expect(sync.hasPending('x', table: 'categories'), isTrue);
      expect(sync.hasPending('x', table: 'nothing-here'), isFalse);
    });
  });

  group('removeFromQueue', () {
    test('drops the queued action and its retry bookkeeping', () async {
      final sync = SyncService();
      await sync.addToQueue(
        id: 'a',
        action: SyncActionType.delete,
        table: 'tasks',
        payload: {'id': 'a'},
      );

      await sync.removeFromQueue(table: 'tasks', id: 'a');

      expect(sync.hasPending('a'), isFalse);
      expect(box.isEmpty, isTrue);
      expect(sync.pendingCount, 0);
    });

    test('is a no-op when nothing is queued', () async {
      final sync = SyncService();
      await sync.removeFromQueue(table: 'tasks', id: 'missing');
      expect(box.isEmpty, isTrue);
    });
  });
}
