import 'package:flutter_test/flutter_test.dart';
import 'package:helm/models/hive_models.dart' as hive_model;
import 'package:helm/models/unified_task.dart';
import 'package:helm/services/task_rules.dart';

Map<String, dynamic> _comment({
  required String userId,
  required DateTime createdAt,
  String? id,
}) {
  return {
    'id': id ?? 'c-$userId-${createdAt.microsecondsSinceEpoch}',
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
  };
}

UnifiedTask _task(String id, {String title = 'Task'}) {
  return UnifiedTask.fromHive(
    hive_model.Task(id: id, title: title, createdAt: DateTime.utc(2026, 1, 1)),
  );
}

void main() {
  group('comment limit (2 per user per task update)', () {
    final updatedAt = DateTime.utc(2026, 10, 29, 12);

    test('counts only comments at or after the task update', () {
      final comments = [
        _comment(userId: 'me', createdAt: updatedAt.subtract(const Duration(minutes: 1))),
        _comment(userId: 'me', createdAt: updatedAt),
        _comment(userId: 'me', createdAt: updatedAt.add(const Duration(minutes: 1))),
      ];

      expect(
        countRecentComments(comments: comments, userId: 'me', updatedAt: updatedAt),
        2,
      );
    });

    test('ignores other users', () {
      final comments = [
        _comment(userId: 'someone-else', createdAt: updatedAt),
        _comment(userId: 'someone-else', createdAt: updatedAt),
        _comment(userId: 'me', createdAt: updatedAt),
      ];

      expect(
        countRecentComments(comments: comments, userId: 'me', updatedAt: updatedAt),
        1,
      );
    });

    test('reached at exactly two', () {
      final comments = [
        _comment(userId: 'me', createdAt: updatedAt),
        _comment(userId: 'me', createdAt: updatedAt.add(const Duration(seconds: 1))),
      ];

      expect(
        isCommentLimitReached(comments: comments, userId: 'me', updatedAt: updatedAt),
        isTrue,
      );
    });

    test('not reached after the task is updated (slots reset)', () {
      final old = [
        _comment(userId: 'me', createdAt: updatedAt),
        _comment(userId: 'me', createdAt: updatedAt.add(const Duration(seconds: 1))),
      ];
      final newUpdatedAt = updatedAt.add(const Duration(minutes: 5));

      expect(
        isCommentLimitReached(comments: old, userId: 'me', updatedAt: newUpdatedAt),
        isFalse,
      );
    });

    test('unparseable timestamps do not consume quota', () {
      final comments = [
        {'id': 'x', 'user_id': 'me', 'created_at': null},
        {'id': 'y', 'user_id': 'me', 'created_at': 'not a date'},
      ];

      expect(
        countRecentComments(comments: comments, userId: 'me', updatedAt: updatedAt),
        0,
      );
    });

    test('signed-out user has no quota', () {
      final comments = [_comment(userId: 'me', createdAt: updatedAt)];
      expect(
        countRecentComments(comments: comments, userId: null, updatedAt: updatedAt),
        0,
      );
    });
  });

  group('findTaskById', () {
    test('resolves the latest value for an id', () {
      final oldTask = _task('a', title: 'Old title');
      final newTask = _task('a', title: 'New title');
      final tasks = [newTask, _task('b')];

      final resolved = findTaskById(tasks, 'a');
      expect(resolved?.title, 'New title');
      expect(resolved, isNot(same(oldTask)));
    });

    test('returns null for a missing id', () {
      expect(findTaskById([_task('a')], 'missing'), isNull);
    });

    test('returns null when the list is not loaded yet', () {
      expect(findTaskById(null, 'a'), isNull);
    });
  });
}
