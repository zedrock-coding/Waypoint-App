import 'package:flutter/foundation.dart';

/// Abstract contract for the on-device fallback extractor.
abstract class NeedleEngine {
  Future<bool> initialize();
  bool get isReady;

  /// Transcribes raw audio locally when offline.
  ///
  /// No on-device ASR model ships with Waypoint, so the implementation returns
  /// `null`; callers fall back to typed or speech-to-text input.
  Future<String?> transcribeAudioLocally(Uint8List audioBytes);

  /// Performs fast, grammar-constrained task slot filling
  Future<Map<String, dynamic>?> extractTask({
    required String input,
    Map<String, dynamic>? templateContext,
    List<Map<String, dynamic>> availableCommunities = const [],
    List<Map<String, dynamic>> availableMembers = const [],
  });

  /// Expands subtask blueprint into discrete actionable subtask strings
  Future<List<String>> expandSubtasks({
    required String title,
    required List<String> templateHints,
  });
}

/// Deterministic grammar/rule parser used when the AI backend is unavailable.
///
/// This is a keyword heuristic, not a neural model: it recognises a small
/// vocabulary (priority words, today/tomorrow/weekday names, community and
/// member names) and fills a fixed schema. It is fast, offline, and
/// predictable, and it is the reason the app still works with no network.
class LocalHeuristicParser implements NeedleEngine {
  bool _initialized = false;

  @override
  bool get isReady => _initialized;

  @override
  Future<bool> initialize() async {
    try {
      // Nothing to load: the parser is pure Dart with no weights or FFI
      // bindings. Kept async so a real on-device model can drop in later
      // without changing callers.
      _initialized = true;
      debugPrint('LocalHeuristicParser ready');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize LocalHeuristicParser: $e');
      _initialized = false;
      return false;
    }
  }

  @override
  Future<String?> transcribeAudioLocally(Uint8List audioBytes) async {
    if (audioBytes.length < 100) return null;
    // No on-device ASR is bundled. Returning null tells the caller to use the
    // text it already has (STT transcript or typed input).
    return null;
  }

  @override
  Future<Map<String, dynamic>?> extractTask({
    required String input,
    Map<String, dynamic>? templateContext,
    List<Map<String, dynamic>> availableCommunities = const [],
    List<Map<String, dynamic>> availableMembers = const [],
  }) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    // 1. If Gemini provided an unjumbled templateContext, blend it into the deterministic schema
    String title = templateContext?['title'] ?? '';
    String? description = templateContext?['description'];
    String? dueDateStr = templateContext?['due_date']?.toString();
    String priorityStr = templateContext?['priority'] ?? 'MEDIUM';
    String? communityId = templateContext?['community_id']?.toString();
    String? assigneeId = templateContext?['assignee_id']?.toString();

    final lower = cleanInput.toLowerCase();
    final extractedTime = _extractTime(cleanInput) ??
        (templateContext?['due_time'] != null ? _extractTime(templateContext!['due_time'].toString()) : null) ??
        (templateContext?['time'] != null ? _extractTime(templateContext!['time'].toString()) : null);

    // 2. Rule-based priority extraction
    if (templateContext?['priority'] == null) {
      if (RegExp(r'\b(urgent|critical|asap|high(\s+priority)?)\b').hasMatch(lower)) {
        priorityStr = 'HIGH';
      } else if (RegExp(r'\b(low(\s+priority)?|minor|when possible)\b').hasMatch(lower)) {
        priorityStr = 'LOW';
      } else {
        priorityStr = 'MEDIUM';
      }
    }

    // 3. Rule-based date and time parsing
    final now = DateTime.now();
    final inHoursMatch = RegExp(r'\bin\s+(\d+)\s+hours?\b').firstMatch(lower);
    final inMinsMatch = RegExp(r'\bin\s+(\d+)\s+(?:mins?|minutes?)\b').firstMatch(lower);

    if (inHoursMatch != null && (dueDateStr == null || dueDateStr.isEmpty || dueDateStr == 'null')) {
      final hoursToAdd = int.parse(inHoursMatch.group(1)!);
      final target = now.add(Duration(hours: hoursToAdd));
      dueDateStr = _formatDateTime(target, (hour: target.hour, minute: target.minute));
    } else if (inMinsMatch != null && (dueDateStr == null || dueDateStr.isEmpty || dueDateStr == 'null')) {
      final minsToAdd = int.parse(inMinsMatch.group(1)!);
      final target = now.add(Duration(minutes: minsToAdd));
      dueDateStr = _formatDateTime(target, (hour: target.hour, minute: target.minute));
    } else if (dueDateStr != null && dueDateStr.isNotEmpty && dueDateStr != 'null') {
      final hasTimeInTemplate = RegExp(r'[T\s]\d{1,2}:\d{2}').hasMatch(dueDateStr);
      if (!hasTimeInTemplate && extractedTime != null) {
        final parsedDate = DateTime.tryParse(dueDateStr);
        if (parsedDate != null) {
          dueDateStr = _formatDateTime(parsedDate, extractedTime);
        } else {
          final h = extractedTime.hour.toString().padLeft(2, '0');
          final m = extractedTime.minute.toString().padLeft(2, '0');
          dueDateStr = '${dueDateStr.trim()}T$h:$m:00';
        }
      }
    } else {
      DateTime? date = _extractDate(lower, now);
      if (date == null && extractedTime != null) {
        final targetToday = DateTime(now.year, now.month, now.day, extractedTime.hour, extractedTime.minute);
        date = targetToday.isBefore(now)
            ? DateTime(now.year, now.month, now.day).add(const Duration(days: 1))
            : DateTime(now.year, now.month, now.day);
      }

      if (date != null) {
        if (extractedTime != null) {
          dueDateStr = _formatDateTime(date, extractedTime);
        } else {
          dueDateStr = _formatDate(date);
        }
      }
    }

    // 4. Entity matching (communities and members)
    if (communityId == null && availableCommunities.isNotEmpty) {
      for (final comm in availableCommunities) {
        final name = (comm['name'] ?? '').toString().toLowerCase();
        if (name.isNotEmpty && lower.contains(name)) {
          communityId = comm['id']?.toString();
          break;
        }
      }
    }

    if (assigneeId == null && availableMembers.isNotEmpty) {
      for (final mem in availableMembers) {
        final name = (mem['full_name'] ?? mem['name'] ?? '').toString().toLowerCase();
        if (name.isNotEmpty && lower.contains(name)) {
          assigneeId = mem['id']?.toString();
          break;
        }
      }
    }

    // 5. Subtask Extraction (from template context, bullet lists, multi-step sequences, or delimiter heuristics)
    List<String> subtasks = [];
    if (templateContext?['subtasks'] is List) {
      subtasks = (templateContext!['subtasks'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (subtasks.isEmpty) {
      // 5a. Bullet list or numbered list extraction (e.g. lines with -, *, 1., 2.)
      final lines = cleanInput.split('\n').map((l) => l.trim()).toList();
      if (lines.length >= 2) {
        final bulletItems = lines
            .where((l) => l.startsWith('- ') || l.startsWith('* ') || RegExp(r'^\d+[\.\)]\s+').hasMatch(l))
            .map((l) => l.replaceFirst(RegExp(r'^(?:[-\*]|\d+[\.\)])\s*'), '').trim())
            .where((l) => l.isNotEmpty && l.length > 1)
            .toList();
        if (bulletItems.length >= 2) {
          subtasks = bulletItems;
          if (title.isEmpty) {
            final firstNonBullet = lines.firstWhere(
              (l) => !l.startsWith('- ') && !l.startsWith('* ') && !RegExp(r'^\d+[\.\)]\s+').hasMatch(l),
              orElse: () => '',
            );
            if (firstNonBullet.isNotEmpty) {
              title = firstNonBullet.replaceAll(RegExp(r'[:;]$'), '').trim();
            }
          }
        }
      }
    }

    if (subtasks.isEmpty) {
      // 5b. Multi-step phrases (e.g. "first do X then do Y and finally do Z")
      final multiStepRegex = RegExp(
        r'\bfirst(?:ly)?\s+(.+?)\s+then\s+(.+?)(?:\s+then\s+(.+?))?(?:\s+(?:and\s+)?(?:finally|lastly)\s+(.+))?$',
        caseSensitive: false,
      );
      final stepMatch = multiStepRegex.firstMatch(cleanInput);
      if (stepMatch != null) {
        final List<String> extracted = [];
        for (int i = 1; i <= stepMatch.groupCount; i++) {
          final raw = stepMatch.group(i)?.trim();
          if (raw != null && raw.isNotEmpty) {
            final cleaned = raw
                .replaceAll(RegExp(r'[,;.\s]+$'), '')
                .replaceAll(RegExp(r'^(?:and|then)\s+', caseSensitive: false), '')
                .trim();
            if (cleaned.isNotEmpty && cleaned.length > 1) {
              extracted.add(cleaned);
            }
          }
        }
        if (extracted.length >= 2) {
          subtasks = extracted;
          if (title.isEmpty) {
            final prefix = cleanInput.substring(0, stepMatch.start).trim();
            final cleanPrefix = prefix
                .replaceAll(RegExp(r'[:;,\s]+$'), '')
                .replaceAll(
                  RegExp(
                    r'^(?:remind me to|create task to|create task|add task to|add task|make a task to|make a task)\s+',
                    caseSensitive: false,
                  ),
                  '',
                )
                .trim();
            if (cleanPrefix.isNotEmpty) {
              title = cleanPrefix;
            } else {
              final first = extracted.first;
              final capitalized = first[0].toUpperCase() + first.substring(1);
              title = '$capitalized & next steps';
            }
          }
        }
      }
    }

    if (subtasks.isEmpty) {
      // 5c. Delimiter matching (e.g. "Title: item 1, item 2, and item 3")
      final delimiterMatch = RegExp(r'^(.+?)[:;]\s*(.+)$').firstMatch(cleanInput);
      if (delimiterMatch != null) {
        final prefix = delimiterMatch.group(1)!.trim();
        final suffix = delimiterMatch.group(2)!.trim();

        // 1. Try splitting on comma, semicolon, or newline
        List<String> items = suffix
            .split(RegExp(r'[,;\n]'))
            .map((e) => e
                .replaceAll(RegExp(r'^(?:[-\*]|\d+[\.\)])\s*'), '')
                .replaceAll(RegExp(r'^\s*and\s+', caseSensitive: false), '')
                .replaceAll(RegExp(r'[,;.\s]+$'), '')
                .trim())
            .where((e) => e.isNotEmpty && e.length > 1)
            .toList();

        // 2. If no commas present, fallback to " and "
        if (items.length < 2 && RegExp(r'\band\b', caseSensitive: false).hasMatch(suffix)) {
          items = suffix
              .split(RegExp(r'\band\b', caseSensitive: false))
              .map((e) => e
                  .replaceAll(RegExp(r'^(?:[-\*]|\d+[\.\)])\s*'), '')
                  .replaceAll(RegExp(r'[,;.\s]+$'), '')
                  .trim())
              .where((e) => e.isNotEmpty && e.length > 1)
              .toList();
        }

        if (items.length >= 2) {
          subtasks = items;
          if (title.isEmpty) {
            title = prefix;
          }
        }
      }
    }

    // 6. Title & Description Cleanup
    if (title.isEmpty) {
      // Rephrase clean title
      var candidate = cleanInput
          .replaceAll(RegExp(r'\b(urgent|high priority|low priority|asap|today|tomorrow)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\bin\s+\d+\s+(?:hours?|mins?|minutes?)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:am|pm)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\bat\s+\d{1,2}(?::\d{2})?\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(?:on\s+)?(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?(?:\s*,?\s*\d{4})?\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'^(?:remind me to|create task to|create task|add task to|add task|make a task to|make a task|make the task to|make the task)\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (candidate.length > 50) {
        title = candidate.substring(0, 50).trim();
        description ??= cleanInput;
      } else {
        title = candidate.isNotEmpty ? candidate : 'New Task';
      }
    }

    final bool clarificationNeeded = templateContext?['clarification_needed'] == true;
    final String? clarificationMessage = templateContext?['clarification_message']?.toString();

    // Guaranteed schema conformance for the caller
    return {
      'title': title,
      'description': description,
      'due_date': dueDateStr,
      'priority': priorityStr.toUpperCase(),
      'community_id': communityId,
      'assignee_id': assigneeId,
      'subtasks': subtasks,
      'clarification_needed': clarificationNeeded,
      'clarification_message': clarificationMessage,
    };
  }

  @override
  Future<List<String>> expandSubtasks({
    required String title,
    required List<String> templateHints,
  }) async {
    if (templateHints.isNotEmpty) {
      return templateHints
          .map((hint) => hint.trim())
          .where((hint) => hint.isNotEmpty)
          .toList();
    }

    final lower = title.toLowerCase();
    if (RegExp(r'\b(launch|deploy|release|ship|rollout)\b').hasMatch(lower)) {
      return [
        'Complete pre-launch checklist for $title',
        'Deploy to staging and verify smoke tests',
        'Execute production rollout',
        'Monitor telemetry and error rates',
      ];
    }
    if (RegExp(r'\b(test|qa|verify|audit|validation)\b').hasMatch(lower)) {
      return [
        'Define test matrix and scenarios for $title',
        'Execute functional and regression test suite',
        'Document bugs and verify patches',
      ];
    }
    if (RegExp(r'\b(meet|meeting|interview|sync|call|presentation)\b').hasMatch(lower)) {
      return [
        'Prepare agenda and materials for $title',
        'Conduct session and capture action items',
        'Send summary notes and next steps',
      ];
    }
    if (RegExp(r'\b(bug|fix|patch|issue|error|hotfix|crash)\b').hasMatch(lower)) {
      return [
        'Reproduce and isolate root cause for $title',
        'Implement code fix and unit tests',
        'Verify resolution in staging environment',
      ];
    }

    // Fallback template items derived from title
    return [
      'Scope requirements for $title',
      'Implement core solution',
      'Verify and mark complete',
    ];
  }

  ({int hour, int minute})? _extractTime(String text) {
    final lower = text.toLowerCase();

    // 1. 12-hour format with AM/PM (e.g. "5 pm", "5:30 pm", "5pm", "11:00 am")
    final amPmRegex = RegExp(r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b', caseSensitive: false);
    final amPmMatch = amPmRegex.firstMatch(lower);
    if (amPmMatch != null) {
      int hour = int.parse(amPmMatch.group(1)!);
      final minute = amPmMatch.group(2) != null ? int.parse(amPmMatch.group(2)!) : 0;
      final isPm = amPmMatch.group(3)!.toLowerCase() == 'pm';
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return (hour: hour, minute: minute);
      }
    }

    // 2. 24-hour format (e.g. "at 17:00", "17:30")
    final h24Regex = RegExp(r'\b(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)\b');
    final h24Match = h24Regex.firstMatch(lower);
    if (h24Match != null) {
      final hour = int.parse(h24Match.group(1)!);
      final minute = int.parse(h24Match.group(2)!);
      return (hour: hour, minute: minute);
    }

    // 3. "at <hour>" without AM/PM (e.g. "at 5")
    final atHourRegex = RegExp(r'\bat\s+(\d{1,2})\b');
    final atHourMatch = atHourRegex.firstMatch(lower);
    if (atHourMatch != null) {
      int hour = int.parse(atHourMatch.group(1)!);
      if (hour >= 1 && hour <= 12) {
        if (hour >= 1 && hour <= 6) hour += 12; // Assume afternoon/evening for low numbers
        return (hour: hour, minute: 0);
      }
    }

    // 4. Keyword times
    if (RegExp(r'\b(noon|midday)\b').hasMatch(lower)) {
      return (hour: 12, minute: 0);
    }
    if (RegExp(r'\bmidnight\b').hasMatch(lower)) {
      return (hour: 0, minute: 0);
    }
    if (RegExp(r'\bmorning\b').hasMatch(lower)) {
      return (hour: 9, minute: 0);
    }
    if (RegExp(r'\bafternoon\b').hasMatch(lower)) {
      return (hour: 14, minute: 0);
    }
    if (RegExp(r'\bevening\b').hasMatch(lower)) {
      return (hour: 18, minute: 0);
    }
    if (RegExp(r'\b(night|tonight)\b').hasMatch(lower)) {
      return (hour: 20, minute: 0);
    }

    return null;
  }

  DateTime? _extractDate(String lower, DateTime now) {
    if (lower.contains('today')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (lower.contains('tomorrow')) {
      final next = now.add(const Duration(days: 1));
      return DateTime(next.year, next.month, next.day);
    }

    final inDaysMatch = RegExp(r'\bin\s+(\d+)\s+days?\b').firstMatch(lower);
    if (inDaysMatch != null) {
      final days = int.parse(inDaysMatch.group(1)!);
      final next = now.add(Duration(days: days));
      return DateTime(next.year, next.month, next.day);
    }

    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (int i = 0; i < days.length; i++) {
      if (lower.contains(days[i])) {
        int targetWeekday = i + 1;
        int daysToAdd = (targetWeekday - now.weekday + 7) % 7;
        if (daysToAdd == 0) daysToAdd = 7;
        final next = now.add(Duration(days: daysToAdd));
        return DateTime(next.year, next.month, next.day);
      }
    }

    const monthNames = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };

    final m1 = RegExp(r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(\d{4}))?\b').firstMatch(lower);
    if (m1 != null) {
      final mStr = m1.group(1)!;
      final month = monthNames[mStr]!;
      final day = int.parse(m1.group(2)!);
      final year = m1.group(3) != null ? int.parse(m1.group(3)!) : (month < now.month ? now.year + 1 : now.year);
      if (day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    final m2 = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?:\s*,?\s*(\d{4}))?\b').firstMatch(lower);
    if (m2 != null) {
      final day = int.parse(m2.group(1)!);
      final mStr = m2.group(2)!;
      final month = monthNames[mStr]!;
      final year = m2.group(3) != null ? int.parse(m2.group(3)!) : (month < now.month ? now.year + 1 : now.year);
      if (day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    final isoMatch = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(lower);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      return DateTime(y, m, d);
    }

    return null;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTime(DateTime date, ({int hour, int minute}) time) {
    final d = _formatDate(date);
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${d}T$h:$m:00';
  }
}
