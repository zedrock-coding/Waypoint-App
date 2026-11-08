// lib/features/task/domain/services/task_extraction_parser.dart

import '../models/extracted_task_result.dart';
import '../models/task.dart';

class TaskExtractionParser {
  final DateTime clientTimestamp;
  final String timeZoneOffset;

  TaskExtractionParser({
    DateTime? anchor,
    DateTime? clientTimestamp,
    this.timeZoneOffset = '+05:30',
  }) : clientTimestamp = anchor ?? clientTimestamp ?? DateTime.now();

  ExtractedTaskResult parse(String input) {
    // 1. Meta-Prefix Strip
    final prefixRegex = RegExp(
      r'^(create\s+(a\s+)?task\s+(saying\s+that\s+|to\s+)?|remind\s+me\s+to\s+|please\s+add\s+(a\s+)?task\s+to\s+|add\s+(a\s+)?task\s+(to\s+)?|schedule\s+(a\s+)?(task\s+to\s+|task\s+)?|make\s+(a\s+)?task\s+(to\s+)?)',
      caseSensitive: false,
    );
    var cleaned = input.trim().replaceAll(prefixRegex, '').trim();

    // 2. Priority Extraction
    TaskPriority priorityEnum = TaskPriority.medium;
    bool priorityFound = false;

    final urgentRegex = RegExp(r'\b(urgent|critical|asap)\b', caseSensitive: false);
    final highRegex = RegExp(r'\b(high(\s+priority)?|keep\s+this\s+high\s+priority|priority\s+high)\b', caseSensitive: false);
    final mediumRegex = RegExp(r'\b(medium(\s+priority)?|normal(\s+priority)?|keep\s+this\s+medium\s+priority|priority\s+medium)\b', caseSensitive: false);
    final lowRegex = RegExp(r'\b(low(\s+priority)?|minor|keep\s+this\s+low\s+priority|priority\s+low)\b', caseSensitive: false);

    if (urgentRegex.hasMatch(cleaned)) {
      priorityEnum = TaskPriority.urgent;
      priorityFound = true;
    } else if (highRegex.hasMatch(cleaned) ||
        (RegExp(r'\bhigh\b', caseSensitive: false).hasMatch(cleaned) &&
            RegExp(r'\bpriority\b', caseSensitive: false).hasMatch(cleaned))) {
      priorityEnum = TaskPriority.high;
      priorityFound = true;
    } else if (mediumRegex.hasMatch(cleaned)) {
      priorityEnum = TaskPriority.medium;
      priorityFound = true;
    } else if (lowRegex.hasMatch(cleaned)) {
      priorityEnum = TaskPriority.low;
      priorityFound = true;
    }

    final priorityValue = priorityEnum.name.toLowerCase();

    // 3. Relative Time & Weekday Mapping
    DateTime? dueDate;
    bool dueDateFound = false;

    final lower = cleaned.toLowerCase();
    int? hour;
    int? minute;

    // Standard 12-hour clock (e.g. 5pm, 5:30 pm, 10 am)
    final timeAmPmMatch = RegExp(
      r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(lower);

    // 24-hour clock (e.g. 17:00, 14:30)
    final time24Match = RegExp(
      r'\b(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)\b',
      caseSensitive: false,
    ).firstMatch(lower);

    if (timeAmPmMatch != null) {
      int h = int.parse(timeAmPmMatch.group(1)!);
      final m = timeAmPmMatch.group(2) != null ? int.parse(timeAmPmMatch.group(2)!) : 0;
      final isPm = timeAmPmMatch.group(3)!.toLowerCase() == 'pm';
      if (isPm && h < 12) h += 12;
      if (!isPm && h == 12) h = 0;
      hour = h;
      minute = m;
      dueDateFound = true;
    } else if (time24Match != null) {
      hour = int.parse(time24Match.group(1)!);
      minute = int.parse(time24Match.group(2)!);
      dueDateFound = true;
    }

    if (hour == null) {
      if (lower.contains('this morning') || lower.contains('morning')) {
        hour = 9;
        minute = 0;
      } else if (lower.contains('this afternoon') || lower.contains('afternoon')) {
        hour = 14;
        minute = 0;
      } else if (lower.contains('this evening') || lower.contains('evening')) {
        hour = 18;
        minute = 0;
      } else if (lower.contains('tonight')) {
        hour = 20;
        minute = 0;
      } else if (lower.contains('night')) {
        hour = 21;
        minute = 0;
      }
    }

    // Base date anchored to client time zone
    DateTime effectiveAnchor = clientTimestamp;
    if (clientTimestamp.isUtc && timeZoneOffset.isNotEmpty) {
      final sign = timeZoneOffset.startsWith('-') ? -1 : 1;
      final parts = timeZoneOffset.replaceAll(RegExp(r'^[+-]'), '').split(':');
      final offsetHours = int.tryParse(parts[0]) ?? 0;
      final offsetMins = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      effectiveAnchor = clientTimestamp.add(Duration(
        hours: sign * offsetHours,
        minutes: sign * offsetMins,
      ));
    }

    DateTime targetDate = DateTime(
      effectiveAnchor.year,
      effectiveAnchor.month,
      effectiveAnchor.day,
    );

    final inHoursMatch =
        RegExp(r'\bin\s+(\d+)\s+hours?\b', caseSensitive: false).firstMatch(lower);
    if (inHoursMatch != null) {
      final hours = int.parse(inHoursMatch.group(1)!);
      dueDate = effectiveAnchor.add(Duration(hours: hours));
      dueDateFound = true;
    } else if (lower.contains('tomorrow')) {
      targetDate = targetDate.add(const Duration(days: 1));
      dueDateFound = true;
    } else if (lower.contains('today') ||
        lower.contains('this evening') ||
        lower.contains('this morning') ||
        lower.contains('this afternoon') ||
        lower.contains('tonight')) {
      dueDateFound = true;
    } else {
      // Weekday recognition
      final weekdayMap = {
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
      };

      bool weekdayFound = false;
      for (final entry in weekdayMap.entries) {
        if (RegExp('\\b(?:next\\s+|on\\s+)?${entry.key}\\b', caseSensitive: false).hasMatch(lower)) {
          int diff = entry.value - effectiveAnchor.weekday;
          if (diff <= 0) diff += 7;
          targetDate = targetDate.add(Duration(days: diff));
          dueDateFound = true;
          weekdayFound = true;
          break;
        }
      }

      if (!weekdayFound) {
        final inDaysMatch =
            RegExp(r'\bin\s+(\d+)\s+days?\b', caseSensitive: false).firstMatch(cleaned);
        if (inDaysMatch != null) {
          final days = int.parse(inDaysMatch.group(1)!);
          targetDate = targetDate.add(Duration(days: days));
          dueDateFound = true;
        }
      }
    }

    if (inHoursMatch == null) {
      if (hour != null) {
        dueDateFound = true;
        final y = targetDate.year.toString().padLeft(4, '0');
        final m = targetDate.month.toString().padLeft(2, '0');
        final d = targetDate.day.toString().padLeft(2, '0');
        final h = hour.toString().padLeft(2, '0');
        final min = (minute ?? 0).toString().padLeft(2, '0');
        if (clientTimestamp.isUtc) {
          dueDate = DateTime.parse('$y-$m-${d}T$h:$min:00$timeZoneOffset');
        } else {
          dueDate = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            hour,
            minute ?? 0,
          );
        }
      } else if (dueDateFound) {
        final y = targetDate.year.toString().padLeft(4, '0');
        final m = targetDate.month.toString().padLeft(2, '0');
        final d = targetDate.day.toString().padLeft(2, '0');
        if (clientTimestamp.isUtc) {
          dueDate = DateTime.parse('$y-$m-${d}T18:00:00$timeZoneOffset');
        } else {
          dueDate = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            18,
            0,
          );
        }
      }
    }

    // 4. Clean trailing metadata directives from action content
    var content = cleaned;
    content = content.replaceAll(
      RegExp(r',?\s*(keep\s+this\s+|make\s+it\s+|with\s+)?(urgent|critical|high|medium|low)(\s+priority)?', caseSensitive: false),
      '',
    );
    content = content.replaceAll(
      RegExp(r',?\s*(high|urgent|critical|low|medium)\s+priority', caseSensitive: false),
      '',
    );
    content = content.replaceAll(
      RegExp(r',?\s*(and\s+)?(make\s+it\s+due|due|by|on)\s+(this\s+(morning|afternoon|evening)|tonight|today|tomorrow|in\s+\d+\s+(?:days?|hours?))(\s+(morning|afternoon|evening|night))?', caseSensitive: false),
      '',
    );
    content = content.replaceAll(
      RegExp(r',?\s*due\s+(this\s+evening|this\s+morning|this\s+afternoon|tonight|today|tomorrow)', caseSensitive: false),
      '',
    );
    content = content.replaceAll(
      RegExp(r',?\s*(and\s+)?(?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:am|pm)\b', caseSensitive: false),
      '',
    );
    content = content.replaceAll(
      RegExp(r',?\s*(and\s+)?(?:at\s+)?(?:[01]?\d|2[0-3]):[0-5]\d\b', caseSensitive: false),
      '',
    );
    content = content.replaceAll(RegExp(r'[,.\s]+$'), '').trim();

    // 5. Milestone & Subtask Extraction Rules
    // Primary compound conjunctions: "and then also", "and then", "also", "so that we can", "so that", "after that"
    final primaryConjunctionRegex = RegExp(
      r'\s*(?:and\s+then\s+also|and\s+then|and\s+also|also|so\s+that\s+we\s+can|so\s+that|after\s+that)\s*',
      caseSensitive: false,
    );

    var rawClauses = content.split(primaryConjunctionRegex);
    if (rawClauses.length < 2 && RegExp(r'\s+and\s+', caseSensitive: false).hasMatch(content)) {
      final andClauses = content.split(RegExp(r'\s+and\s+', caseSensitive: false));
      if (andClauses.every((c) => c.trim().length > 3)) {
        rawClauses = andClauses;
      }
    }

    final List<ExtractedSubtask> subtasks = [];

    String sanitizeClause(String raw) {
      var s = raw.trim();
      s = s.replaceAll(RegExp(r'^(I\s+need\s+to\s+|we\s+need\s+to\s+|need\s+to\s+|I\s+want\s+to\s+)', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'^(we\s+can\s+|can\s+)', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'^(to\s+)', caseSensitive: false), '');
      s = s.trim();
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
    // Graceful fallback default: If deadline is provided, default priority to medium
    // instead of blocking task creation with another disambiguation cycle.
    if (!priorityFound && !dueDateFound) {
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
      priority: priorityValue,
      subtasks: subtasks,
      missingFields: missingFields,
      disambiguationPrompt: disambiguationPrompt,
    );
  }
}
