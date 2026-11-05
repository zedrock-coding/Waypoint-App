// test/features/task/task_extraction_subtasks_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/models/task.dart';
import 'package:waypoint/features/task/domain/repositories/task_local_repository.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';

void main() {
  group('Task Extraction and Subtasks Persistence Tests', () {
    final clientAnchor = DateTime(2026, 11, 5, 10, 0);

    test('Parser extracts clean title, high priority, evening deadline, and decomposed subtasks', () {
      final parser = TaskExtractionParser(clientTimestamp: clientAnchor);
      const input =
          "create a task to help Priyanshi with Jira and set up her mail system due this evening high priority";

      final result = parser.parse(input);

      // Title must strip command framing
      expect(result.title.toLowerCase().contains('create a task'), false);
      expect(result.title.toLowerCase(), contains('help priyanshi with jira'));

      // Priority and relative time resolution
      expect(result.priority, 'high');
      expect(result.taskPriority, TaskPriority.high);
      expect(result.dueDate, isNotNull);
      expect(result.dueDate!.hour, 18);

      // Decomposed subtasks
      expect(result.subtasks.length, greaterThanOrEqualTo(2));
      final subtaskTitles = result.subtasks.map((s) => s.title.toLowerCase()).toList();
      expect(subtaskTitles.any((t) => t.contains('help priyanshi with jira')), true);
      expect(subtaskTitles.any((t) => t.contains('set up her mail system')), true);
    });

    test('Persists parsed task and child subtasks with foreign key task_id in TaskLocalRepository', () async {
      final parser = TaskExtractionParser(clientTimestamp: clientAnchor);
      const input =
          "create a task to help Priyanshi with Jira and set up her mail system due this evening high priority";

      final result = parser.parse(input);
      final task = result.toTask(id: 'task_test_123');

      final repository = TaskLocalRepository();
      await repository.insertTask(task);

      // Verify parent task in store
      final fetchedTask = await repository.getTask('task_test_123');
      expect(fetchedTask, isNotNull);
      expect(fetchedTask!.id, 'task_test_123');
      expect(fetchedTask.title, contains('help Priyanshi with Jira'));
      expect(fetchedTask.priority, TaskPriority.high);
      expect(fetchedTask.dueDate?.hour, 18);

      // Verify child subtasks in subtasks store with foreign key
      final subtaskRows = await repository.getSubtasksForTask('task_test_123');
      expect(subtaskRows.length, greaterThanOrEqualTo(2));
      for (final row in subtaskRows) {
        expect(row['task_id'], 'task_test_123');
        expect(row['title'], isNotNull);
        expect((row['title'] as String).isNotEmpty, true);
      }
      expect(subtaskRows.any((r) => (r['title'] as String).toLowerCase().contains('jira')), true);
      expect(subtaskRows.any((r) => (r['title'] as String).toLowerCase().contains('mail')), true);
    });
  });
}
