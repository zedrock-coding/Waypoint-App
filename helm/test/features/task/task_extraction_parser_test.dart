// test/features/task/task_extraction_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';

void main() {
  group('Task Extraction Parser Verification', () {
    final anchor = DateTime(2026, 11, 5, 10, 0); // Reference time
    late TaskExtractionParser parser;

    setUp(() {
      parser = TaskExtractionParser(clientTimestamp: anchor);
    });

    test('Strips command framing and decomposes all subtasks from video transcription', () {
      const input = "create a task saying that I need to help Priyanshi with her jira and then also set up her mail system so that we can update the excel sheet for us to have our stipend back in time, keep this high priority and make it due today evening";

      final result = parser.parse(input);

      // Title must be sanitized
      expect(result.title.toLowerCase().startsWith('create a task'), false);
      expect(result.title.contains('Priyanshi'), true);

      // Priority and relative time resolution
      expect(result.priority, 'high');
      expect(result.dueDate, DateTime(2026, 11, 5, 18, 0)); // 6:00 PM evening anchor

      // Verify all 3 subtasks extracted
      expect(result.subtasks.length, greaterThanOrEqualTo(3));
      final subtasksText = result.subtasks.map((s) => s.title.toLowerCase()).toList();
      expect(subtasksText.any((s) => s.contains('jira')), true);
      expect(subtasksText.any((s) => s.contains('mail')), true);
      expect(subtasksText.any((s) => s.contains('excel') || s.contains('stipend')), true);
    });

    test('Missing parameters trigger disambiguation prompt', () {
      const input = "Help Priyanshi finish the spreadsheet";
      final result = parser.parse(input);

      expect(result.missingFields, contains('due_date'));
      expect(result.disambiguationPrompt, isNotNull);
      expect(result.disambiguationPrompt!.isNotEmpty, true);
    });
  });
}

