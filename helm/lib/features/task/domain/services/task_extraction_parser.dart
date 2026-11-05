// lib/features/task/domain/services/task_extraction_parser.dart

import '../models/extracted_task_result.dart';

class TaskExtractionParser {
  final DateTime clientTimestamp;

  TaskExtractionParser({DateTime? clientTimestamp})
      : clientTimestamp = clientTimestamp ?? DateTime.now();

  ExtractedTaskResult parse(String input) {
    // 1. Meta-Prefix Strip
    final prefixRegex = RegExp(
      r'^(create\s+(a\s+)?task\s+(saying\s+that\s+|to\s+)?|remind\s+me\s+to\s+|please\s+add\s+(a\s+)?task\s+to\s+)',
      caseSensitive: false,
    );
    var cleaned = input.trim().replaceAll(prefixRegex, '').trim();

    // 2. Priority Extraction
    String priority = 'medium';
    bool priorityFound = false;

    final urgentRegex = RegExp(r'\b(urgent|critical|asap)\b', caseSensitive: false);
    final highRegex = RegExp(r'\b(high\s+priority|keep\s+this\s+high\s+priority|priority\s+high)\b', caseSensitive: false);
    final mediumRegex = RegExp(r'\b(medium\s+priority|keep\s+this\s+medium\s+priority|priority\s+medium)\b', caseSensitive: false);
    final lowRegex = RegExp(r'\b(low\s+priority|keep\s+this\s+low\s+priority|priority\s+low)\b', caseSensitive: false);

    if (urgentRegex.hasMatch(cleaned)) {
      priority = 'urgent';
      priorityFound = true;
    } else if (highRegex.hasMatch(cleaned) ||
        (RegExp(r'\bhigh\b', caseSensitive: false).hasMatch(cleaned) &&
            RegExp(r'\bpriority\b', caseSensitive: false).hasMatch(cleaned))) {
      priority = 'high';
      priorityFound = true;
    } else if (mediumRegex.hasMatch(cleaned)) {
      priority = 'medium';
      priorityFound = true;
    } else if (lowRegex.hasMatch(cleaned)) {
      priority = 'low';
      priorityFound = true;
    }

    // 3. Relative Time Mapping
    DateTime? dueDate;
    bool dueDateFound = false;

    final lower = cleaned.toLowerCase();
    int? hour;
    int? minute;

    if (lower.contains('morning')) {
      hour = 9;
      minute = 0;
    } else if (lower.contains('afternoon')) {
      hour = 14;
      minute = 0;
    } else if (lower.contains('evening')) {
      hour = 18;
      minute = 0;
    } else if (lower.contains('night')) {
      hour = 21;
      minute = 0;
    }

    DateTime targetDate = DateTime(
      clientTimestamp.year,
      clientTimestamp.month,
      clientTimestamp.day,
    );

    if (lower.contains('tomorrow')) {
      targetDate = targetDate.add(const Duration(days: 1));
      dueDateFound = true;
    } else if (lower.contains('today')) {
      dueDateFound = true;
    } else {
      final inDaysMatch = RegExp(r'\bin\s+(\d+)\s+days?\b', caseSensitive: false).firstMatch(cleaned);
      if (inDaysMatch != null) {
        final days = int.parse(inDaysMatch.group(1)!);
        targetDate = targetDate.add(Duration(days: days));
        dueDateFound = true;
      }
    }

    if (hour != null) {
      dueDateFound = true;
      dueDate = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        hour,
        minute ?? 0,
      );
    } else if (dueDateFound) {
      dueDate = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        18,
        0,
      );
    }

    // 4. Clean trailing metadata directives from action content
    var content = cleaned;
    content = content.replaceAll(
      RegExp(r',?\s*(keep\s+this\s+|make\s+it\s+|with\s+)?(urgent|high|medium|low)\s+priority', caseSensitive: false),
      '',
    );
    content = content.replaceAll(
      RegExp(r',?\s*(and\s+)?(make\s+it\s+due|due|by)\s+(today|tomorrow|in\s+\d+\s+days?)(\s+(morning|afternoon|evening|night))?', caseSensitive: false),
      '',
    );
    content = content.replaceAll(RegExp(r'[,.\s]+$'), '').trim();

    // 5. Milestone & Subtask Extraction Rules
    // Conjunctions: "and then also", "and then", "also", "so that", "after that"
    final conjunctionRegex = RegExp(
      r'\s*(?:and\s+then\s+also|and\s+then|also|so\s+that|after\s+that)\s*',
      caseSensitive: false,
    );

    final rawClauses = content.split(conjunctionRegex);
    final List<ExtractedSubtask> subtasks = [];

    String sanitizeClause(String raw) {
      var s = raw.trim();
      s = s.replaceAll(RegExp(r'^(I\s+need\s+to\s+|we\s+need\s+to\s+|need\s+to\s+|I\s+want\s+to\s+)', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'^(we\s+can\s+|can\s+)', caseSensitive: false), '');
      s = s.trim();
      if (s.isNotEmpty) {
        return s[0].toUpperCase() + s.substring(1);
      }
      return s;
    }

    for (final raw in rawClauses) {
      final sanitized = sanitizeClause(raw);
      if (sanitized.isNotEmpty && sanitized.length > 3) {
        subtasks.add(ExtractedSubtask(title: sanitized, dueDate: dueDate));
      }
    }

    // Derive Core Title
    String title = '';
    if (subtasks.isNotEmpty) {
      title = subtasks.first.title;
    } else {
      title = sanitizeClause(content);
    }

    // 6. Disambiguation Evaluation
    final missingFields = <String>[];
    if (!dueDateFound) {
      missingFields.add('due_date');
    }
    if (!priorityFound) {
      missingFields.add('priority');
    }

    String? disambiguationPrompt;
    if (missingFields.isNotEmpty) {
      if (missingFields.contains('due_date') && missingFields.contains('priority')) {
        disambiguationPrompt = "When would you like this task due, and what is its priority?";
      } else if (missingFields.contains('due_date')) {
        disambiguationPrompt = "When would you like this task to be due?";
      } else if (missingFields.contains('priority')) {
        disambiguationPrompt = "What priority should this task have?";
      }
    }

    return ExtractedTaskResult(
      title: title,
      description: content,
      dueDate: dueDate,
      priority: priority,
      subtasks: subtasks,
      missingFields: missingFields,
      disambiguationPrompt: disambiguationPrompt,
    );
  }
}
