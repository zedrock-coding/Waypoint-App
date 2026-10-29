import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/models/hive_models.dart' as hive_model;
import 'package:waypoint/services/task_merge.dart';

hive_model.Task _task({
  required String id,
  DateTime? updatedAt,
  String? userId = 'user-a',
  String? communityId,
}) {
  return hive_model.Task(
    id: id,
    title: 'Task $id',
    userId: userId,
    communityId: communityId,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: updatedAt,
  );
}

void main() {
  group('shouldApplyRemoteUpdate', () {
    final older = DateTime.utc(2026, 10, 1, 10);
    final newer = DateTime.utc(2026, 10, 2, 10);

    test('remote is newer -> apply', () {
      expect(
        shouldApplyRemoteUpdate(
          localUpdatedAt: older,
          remoteUpdatedAt: newer,
          hasPendingWrite: false,
        ),
        isTrue,
      );
    });

    test('local is newer -> keep local', () {
      expect(
        shouldApplyRemoteUpdate(
          localUpdatedAt: newer,
          remoteUpdatedAt: older,
          hasPendingWrite: false,
        ),
        isFalse,
      );
    });

    test('equal timestamps -> keep local (no churn)', () {
      expect(
        shouldApplyRemoteUpdate(
          localUpdatedAt: older,
          remoteUpdatedAt: older,
          hasPendingWrite: false,
        ),
        isFalse,
      );
    });

    test('pending local write always wins, even against a newer remote', () {
      expect(
        shouldApplyRemoteUpdate(
          localUpdatedAt: older,
          remoteUpdatedAt: newer,
          hasPendingWrite: true,
        ),
        isFalse,
      );
    });

    test('local row without timestamp accepts a timestamped remote', () {
      expect(
        shouldApplyRemoteUpdate(
          localUpdatedAt: null,
          remoteUpdatedAt: newer,
          hasPendingWrite: false,
        ),
        isTrue,
      );
    });

    test('remote without timestamp does not clobber a local timestamp', () {
      expect(
        shouldApplyRemoteUpdate(
          localUpdatedAt: older,
          remoteUpdatedAt: null,
          hasPendingWrite: false,
        ),
        isFalse,
      );
    });

    test('both without timestamps -> remote applies (nothing to compare)', () {
      expect(
        shouldApplyRemoteUpdate(
          localUpdatedAt: null,
          remoteUpdatedAt: null,
          hasPendingWrite: false,
        ),
        isTrue,
      );
    });
  });

  group('localRowsMissingRemotely', () {
    test('returns rows backed by the server that are absent remotely', () {
      final rows = [_task(id: 'a'), _task(id: 'b'), _task(id: 'c')];

      final missing = localRowsMissingRemotely(
        localRows: rows,
        remoteIds: {'a', 'c'},
        hasPendingWrite: (_) => false,
      );

      expect(missing, equals({'b'}));
    });

    test('never deletes a row created offline (no user, no community)', () {
      final rows = [_task(id: 'local-1', userId: null)];

      final missing = localRowsMissingRemotely(
        localRows: rows,
        remoteIds: const {},
        hasPendingWrite: (_) => false,
      );

      expect(missing, isEmpty);
    });

    test('never deletes a row with an unflushed write', () {
      final rows = [_task(id: 'a'), _task(id: 'b')];

      final missing = localRowsMissingRemotely(
        localRows: rows,
        remoteIds: const {'a'},
        hasPendingWrite: (task) => task.id == 'b',
      );

      expect(missing, isEmpty);
    });

    test('community rows are eligible for remote-delete propagation', () {
      final rows = [_task(id: 'comm-1', userId: null, communityId: 'c1')];

      final missing = localRowsMissingRemotely(
        localRows: rows,
        remoteIds: const {},
        hasPendingWrite: (_) => false,
      );

      expect(missing, equals({'comm-1'}));
    });
  });
}
