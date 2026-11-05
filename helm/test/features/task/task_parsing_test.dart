// test/features/task/task_parsing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';

void main() {
  group('Subtask & Temporal Resolution Tests', () {
    final clientAnchor = DateTime.parse('2026-11-05T10:10:00+05:30');

    test('Extracts title, evening deadline, and exactly 3 subtasks', () {
      final parser = TaskExtractionParser(anchor: clientAnchor);
      const input = "create a task saying that I need to help Priyanshi with her jira and then also set up her mail system so that we can update the excel sheet for us to have our stipend back in time, keep this high priority and make it due today evening";

      final result = parser.parse(input);

      expect(result.title.toLowerCase().startsWith('create a task'), false);
      expect(result.priority, 'high');
      expect(result.dueDate, DateTime.parse('2026-11-05T18:00:00+05:30'));
      expect(result.subtasks.length, 3);
      expect(result.subtasks[0].title.toLowerCase(), contains('jira'));
      expect(result.subtasks[1].title.toLowerCase(), contains('mail'));
      expect(result.subtasks[2].title.toLowerCase(), contains('excel'));
    });
  });
}

