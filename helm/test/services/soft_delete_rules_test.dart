import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Soft Delete & Safeguard Rules (Video 4 Safeguard 11: Soft Deletes / Trash Bins)', () {
    test('active filter isolates non-deleted items while trash filter isolates soft-deleted items', () {
      final now = DateTime.now();
      final records = [
        {'id': '1', 'title': 'Active Task 1', 'deleted_at': null},
        {'id': '2', 'title': 'Deleted Task 2', 'deleted_at': now.toIso8601String()},
        {'id': '3', 'title': 'Active Task 3', 'deleted_at': null},
        {'id': '4', 'title': 'Deleted Task 4', 'deleted_at': now.subtract(const Duration(days: 2)).toIso8601String()},
      ];

      final activeTasks = records.where((r) => r['deleted_at'] == null).toList();
      final trashTasks = records.where((r) => r['deleted_at'] != null).toList();

      expect(activeTasks.length, equals(2));
      expect(activeTasks.map((t) => t['id']), containsAll(['1', '3']));

      expect(trashTasks.length, equals(2));
      expect(trashTasks.map((t) => t['id']), containsAll(['2', '4']));
    });

    test('batch ceiling calculation rejects operations exceeding 100 items', () {
      bool isAllowedBatch(int batchSize) {
        const int maxSafeBatchSize = 100;
        return batchSize <= maxSafeBatchSize;
      }

      expect(isAllowedBatch(50), isTrue);
      expect(isAllowedBatch(100), isTrue);
      expect(isAllowedBatch(101), isFalse);
      expect(isAllowedBatch(500), isFalse);
    });
  });
}

