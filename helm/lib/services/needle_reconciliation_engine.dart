class NeedleReconciliationResult {
  final String status; // 'verified' | 'clarification_needed'
  final List<String> reconciliationLog;
  final Map<String, dynamic> task;
  final List<String> missingFields;
  final String? disambiguationPrompt;

  const NeedleReconciliationResult({
    required this.status,
    required this.reconciliationLog,
    required this.task,
    required this.missingFields,
    this.disambiguationPrompt,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'reconciliation_log': reconciliationLog,
        'task': task,
        'missing_fields': missingFields,
        if (disambiguationPrompt != null)
          'disambiguation_prompt': disambiguationPrompt,
      };
}

class NeedleReconciliationEngine {
  /// Reconciles raw STT speech transcript with preliminary Gemini JSON extraction
  /// anchored against client temporal and operational context header.
  static NeedleReconciliationResult reconcile({
    required String rawTranscript,
    required Map<String, dynamic> geminiTaskJson,
    required Map<String, dynamic> contextHeader,
  }) {
    final List<String> log = [];
    final List<String> missingFields = [];

    final cleanRaw = rawTranscript.trim();

    // 1. Context Anchor Header Extraction
    final clientTimestampStr = contextHeader['client_timestamp']?.toString();
    DateTime anchor = DateTime.now();
    if (clientTimestampStr != null && clientTimestampStr.isNotEmpty) {
      try {
        anchor = DateTime.parse(clientTimestampStr);
      } catch (_) {
        anchor = DateTime.now();
      }
    }

    final accessibleMembers = (contextHeader['accessible_members'] as List?) ?? [];
    final accessibleCommunities = (contextHeader['accessible_communities'] as List?) ?? [];

    // Check for completely empty / unintelligible input
    if (cleanRaw.isEmpty &&
        (geminiTaskJson['title'] == null ||
            geminiTaskJson['title'].toString().trim().isEmpty ||
            geminiTaskJson['title'] == 'Voice Task' ||
            geminiTaskJson['title'] == 'New Task')) {
      return NeedleReconciliationResult(
        status: 'clarification_needed',
        reconciliationLog: ['Raw transcript is empty and preliminary title is missing.'],
        task: _buildTaskMap(
          title: '',
          description: null,
          dueDate: null,
          priority: 'medium',
          assignee: null,
          communityId: null,
          subtasks: [],
        ),
        missingFields: ['title'],
        disambiguationPrompt: 'What task would you like to create?',
      );
    }

    // 2. Title Stripping & Sanitization
    String candidateTitle = (geminiTaskJson['title'] ?? '').toString().trim();
    if (candidateTitle.isEmpty ||
        candidateTitle == 'Voice Task' ||
        candidateTitle == 'New Task') {
      candidateTitle = cleanRaw;
    }

    final sanitizedTitle = _sanitizeTitle(candidateTitle, cleanRaw, log);

    // 3. Relative Date & Time Normalization
    final resolvedDueDate = _normalizeDueDate(
      rawTranscript: cleanRaw,
      geminiDueDate: geminiTaskJson['due_date']?.toString(),
      geminiDueTime: (geminiTaskJson['due_time'] ?? geminiTaskJson['time'])?.toString(),
      anchor: anchor,
      log: log,
    );

    // 4. Priority Normalization
    final resolvedPriority = _normalizePriority(
      rawTranscript: cleanRaw,
      geminiPriority: geminiTaskJson['priority']?.toString(),
      log: log,
    );

    // 5. Entity Resolution (Assignee & Community)
    final resolvedAssignee = _resolveAssignee(
      rawTranscript: cleanRaw,
      geminiAssignee: (geminiTaskJson['assignee'] ?? geminiTaskJson['assignee_id'])?.toString(),
      members: accessibleMembers,
      log: log,
    );

    final resolvedCommunity = _resolveCommunity(
      rawTranscript: cleanRaw,
      geminiCommunity: (geminiTaskJson['community'] ?? geminiTaskJson['community_id'])?.toString(),
      communities: accessibleCommunities,
      log: log,
    );

    // 6. Subtask Milestone Decomposition
    final resolvedSubtasks = _decomposeSubtasks(
      rawTranscript: cleanRaw,
      geminiSubtasks: geminiTaskJson['subtasks'],
      defaultDueDate: resolvedDueDate,
      log: log,
    );

    // 7. Description Reconciliation
    String? resolvedDescription = geminiTaskJson['description']?.toString().trim();
    if (resolvedDescription == null || resolvedDescription.isEmpty || resolvedDescription == 'null') {
      if (cleanRaw.length > sanitizedTitle.length && cleanRaw.isNotEmpty) {
        resolvedDescription = cleanRaw;
      } else {
        resolvedDescription = null;
      }
    }

    final taskMap = _buildTaskMap(
      title: sanitizedTitle,
      description: resolvedDescription,
      dueDate: resolvedDueDate,
      priority: resolvedPriority,
      assignee: resolvedAssignee,
      communityId: resolvedCommunity,
      subtasks: resolvedSubtasks,
    );

    // 8. Ambiguity Evaluation
    final bool rawClarificationNeeded = geminiTaskJson['clarification_needed'] == true;
    final String? geminiClarificationMsg = geminiTaskJson['clarification_message']?.toString();

    if (sanitizedTitle.isEmpty || sanitizedTitle.length < 2) {
      missingFields.add('title');
      return NeedleReconciliationResult(
        status: 'clarification_needed',
        reconciliationLog: log..add('Title missing or incomplete after sanitization.'),
        task: taskMap,
        missingFields: missingFields,
        disambiguationPrompt: geminiClarificationMsg ?? 'What is the title or goal of this task?',
      );
    }

    if (rawClarificationNeeded) {
      if (resolvedDueDate == null &&
          (cleanRaw.toLowerCase().contains('remind') ||
              cleanRaw.toLowerCase().contains('schedule') ||
              geminiClarificationMsg != null)) {
        missingFields.add('due_date');
        return NeedleReconciliationResult(
          status: 'clarification_needed',
          reconciliationLog: log..add('Clarification needed for missing due date/time.'),
          task: taskMap,
          missingFields: missingFields,
          disambiguationPrompt: geminiClarificationMsg ?? 'When is this task due?',
        );
      }
    }

    return NeedleReconciliationResult(
      status: 'verified',
      reconciliationLog: log..add('Task verified and fully reconciled against transcript.'),
      task: taskMap,
      missingFields: [],
      disambiguationPrompt: null,
    );
  }

  static String _sanitizeTitle(String title, String raw, List<String> log) {
    String t = title;

    final metaPrefixes = [
      RegExp(r'^(?:please\s+)?(?:could you\s+)?(?:remind me to|remind me)\s+', caseSensitive: false),
      RegExp(r'^(?:please\s+)?(?:could you\s+)?(?:create a task saying|create a task to|create a task|create task to|create task)\s+', caseSensitive: false),
      RegExp(r'^(?:please\s+)?(?:could you\s+)?(?:add a task saying|add a task to|add a task|add task to|add task)\s+', caseSensitive: false),
      RegExp(r'^(?:please\s+)?(?:could you\s+)?(?:make a task saying|make a task to|make a task|make the task to|make the task)\s+', caseSensitive: false),
      RegExp(r'^(?:please\s+)?(?:could you\s+)?(?:set a reminder for|set a reminder to|set a reminder)\s+', caseSensitive: false),
      RegExp(r'^(?:please\s+)?(?:could you\s+)?(?:schedule a task to|schedule a task|schedule to|schedule)\s+', caseSensitive: false),
      RegExp(r'^(?:please\s+)?(?:could you\s+)?(?:i need to|we need to|i want to|we want to)\s+', caseSensitive: false),
      RegExp(r'^(?:please\s+)', caseSensitive: false),
    ];

    bool stripped = false;
    for (final reg in metaPrefixes) {
      if (reg.hasMatch(t)) {
        t = t.replaceAll(reg, '').trim();
        stripped = true;
      }
    }

    // Strip trailing punctuation & quotes
    t = t.replaceAll(RegExp(r'^["\s]+|["\s.,;:]+$'), '').trim();

    // Strip temporal keywords if attached at tail
    final trailingTemporal = RegExp(
      r'\s+(?:by|at|on|for)?\s*(?:today|tonight|tomorrow|in \d+\s+(?:hours?|minutes?|mins?)|this\s+[a-zA-Z]+|next\s+[a-zA-Z]+|\d{1,2}(?::\d{2})?\s*(?:am|pm)?)$',
      caseSensitive: false,
    );
    if (trailingTemporal.hasMatch(t)) {
      t = t.replaceAll(trailingTemporal, '').trim();
      stripped = true;
    }

    // Strip priority suffixes
    final trailingPriority = RegExp(
      r'\s+(?:urgently|urgent|asap|high priority|low priority|critical)$',
      caseSensitive: false,
    );
    if (trailingPriority.hasMatch(t)) {
      t = t.replaceAll(trailingPriority, '').trim();
      stripped = true;
    }

    if (stripped) {
      log.add('Sanitized imperative framing and metadata from title: "$t"');
    }

    if (t.isNotEmpty) {
      t = t[0].toUpperCase() + t.substring(1);
    }
    return t;
  }

  static String? _normalizeDueDate({
    required String rawTranscript,
    required String? geminiDueDate,
    required String? geminiDueTime,
    required DateTime anchor,
    required List<String> log,
  }) {
    final lower = rawTranscript.toLowerCase();

    // Relative temporal rules matching anchor
    DateTime? resolvedDate;
    int? resolvedHour;
    int? resolvedMinute;

    // Check specific phrases
    if (lower.contains('today evening')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day);
      resolvedHour = 18;
      resolvedMinute = 0;
      log.add('Detected "today evening" -> mapped to 18:00');
    } else if (lower.contains('tonight')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day);
      resolvedHour = 21;
      resolvedMinute = 0;
      log.add('Detected "tonight" -> mapped to 21:00');
    } else if (lower.contains('today afternoon')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day);
      resolvedHour = 14;
      resolvedMinute = 0;
      log.add('Detected "today afternoon" -> mapped to 14:00');
    } else if (lower.contains('today morning')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day);
      resolvedHour = 9;
      resolvedMinute = 0;
      log.add('Detected "today morning" -> mapped to 09:00');
    } else if (lower.contains('tomorrow morning')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day).add(const Duration(days: 1));
      resolvedHour = 9;
      resolvedMinute = 0;
      log.add('Detected "tomorrow morning" -> mapped to next day 09:00');
    } else if (lower.contains('tomorrow afternoon')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day).add(const Duration(days: 1));
      resolvedHour = 14;
      resolvedMinute = 0;
      log.add('Detected "tomorrow afternoon" -> mapped to next day 14:00');
    } else if (lower.contains('tomorrow evening')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day).add(const Duration(days: 1));
      resolvedHour = 18;
      resolvedMinute = 0;
      log.add('Detected "tomorrow evening" -> mapped to next day 18:00');
    } else if (lower.contains('tomorrow night')) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day).add(const Duration(days: 1));
      resolvedHour = 21;
      resolvedMinute = 0;
      log.add('Detected "tomorrow night" -> mapped to next day 21:00');
    } else if (RegExp(r'\btomorrow\b').hasMatch(lower)) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day).add(const Duration(days: 1));
    } else if (RegExp(r'\btoday\b').hasMatch(lower)) {
      resolvedDate = DateTime(anchor.year, anchor.month, anchor.day);
    }

    // In X hours / minutes
    final inHoursMatch = RegExp(r'\bin\s+(\d+)\s+hours?\b').firstMatch(lower);
    if (inHoursMatch != null) {
      final hours = int.tryParse(inHoursMatch.group(1)!) ?? 0;
      final target = anchor.add(Duration(hours: hours));
      log.add('Detected "in $hours hours" -> mapped to ${target.toIso8601String()}');
      return target.toIso8601String();
    }

    final inMinsMatch = RegExp(r'\bin\s+(\d+)\s+(?:mins?|minutes?)\b').firstMatch(lower);
    if (inMinsMatch != null) {
      final mins = int.tryParse(inMinsMatch.group(1)!) ?? 0;
      final target = anchor.add(Duration(minutes: mins));
      log.add('Detected "in $mins mins" -> mapped to ${target.toIso8601String()}');
      return target.toIso8601String();
    }

    // Clock time extraction: e.g. "at 5 pm", "by 17:30", "at 9:15 am"
    final timeMatch = RegExp(r'\b(?:at|by)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b').firstMatch(lower);
    if (timeMatch != null) {
      int h = int.parse(timeMatch.group(1)!);
      final m = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final meridiem = timeMatch.group(3)?.toLowerCase();
      if (meridiem == 'pm' && h < 12) h += 12;
      if (meridiem == 'am' && h == 12) h = 0;
      resolvedHour = h;
      resolvedMinute = m;
      log.add('Extracted explicit clock time: ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    }

    // If Gemini had preliminary due_date, blend it
    if (geminiDueDate != null && geminiDueDate.isNotEmpty && geminiDueDate != 'null') {
      try {
        final parsed = DateTime.parse(geminiDueDate);
        resolvedDate ??= DateTime(parsed.year, parsed.month, parsed.day);
        if (resolvedHour == null && (geminiDueDate.contains('T') || geminiDueDate.contains(' '))) {
          resolvedHour = parsed.hour;
          resolvedMinute = parsed.minute;
        }
      } catch (_) {}
    }

    if (resolvedDate != null) {
      final finalDt = DateTime(
        resolvedDate.year,
        resolvedDate.month,
        resolvedDate.day,
        resolvedHour ?? 9,
        resolvedMinute ?? 0,
      );
      return finalDt.toIso8601String();
    }

    return null;
  }

  static String _normalizePriority({
    required String rawTranscript,
    required String? geminiPriority,
    required List<String> log,
  }) {
    final lower = rawTranscript.toLowerCase();

    if (RegExp(r'\b(urgent|asap|critical|immediately|emergency|p0)\b').hasMatch(lower)) {
      log.add('Detected urgent priority keyword in raw transcript.');
      return 'urgent';
    }
    if (RegExp(r'\b(high|high\s+priority|crucial|important|p1)\b').hasMatch(lower)) {
      log.add('Detected high priority keyword in raw transcript.');
      return 'high';
    }
    if (RegExp(r'\b(low|low\s+priority|minor|whenever|not\s+urgent|p3)\b').hasMatch(lower)) {
      log.add('Detected low priority keyword in raw transcript.');
      return 'low';
    }

    if (geminiPriority != null) {
      final p = geminiPriority.toLowerCase().trim();
      if (p == 'urgent' || p == 'critical') return 'urgent';
      if (p == 'high') return 'high';
      if (p == 'low') return 'low';
      if (p == 'medium') return 'medium';
    }

    return 'medium';
  }

  static String? _resolveAssignee({
    required String rawTranscript,
    required String? geminiAssignee,
    required List<dynamic> members,
    required List<String> log,
  }) {
    final lower = rawTranscript.toLowerCase();

    for (final member in members) {
      final String id;
      final String name;
      if (member is Map) {
        id = (member['id'] ?? member['userId'] ?? '').toString();
        name = (member['full_name'] ?? member['name'] ?? '').toString();
      } else {
        id = member.toString();
        name = member.toString();
      }

      if (name.isNotEmpty && lower.contains(name.toLowerCase())) {
        log.add('Resolved spoken assignee to "$name" (id: $id)');
        return id.isNotEmpty ? id : name;
      }
    }

    // Check "me" or "myself"
    if (RegExp(r'\b(assign to me|for me|assigned to me)\b').hasMatch(lower)) {
      log.add('Spoken assignee resolved to current user ("me").');
      return 'me';
    }

    if (geminiAssignee != null && geminiAssignee.isNotEmpty && geminiAssignee != 'null') {
      return geminiAssignee;
    }
    return null;
  }

  static String? _resolveCommunity({
    required String rawTranscript,
    required String? geminiCommunity,
    required List<dynamic> communities,
    required List<String> log,
  }) {
    final lower = rawTranscript.toLowerCase();

    for (final community in communities) {
      final String id;
      final String name;
      if (community is Map) {
        id = (community['id'] ?? '').toString();
        name = (community['name'] ?? '').toString();
      } else {
        id = community.toString();
        name = community.toString();
      }

      if (name.isNotEmpty && lower.contains(name.toLowerCase())) {
        log.add('Resolved spoken community to "$name" (id: $id)');
        return id.isNotEmpty ? id : name;
      }
    }

    if (geminiCommunity != null && geminiCommunity.isNotEmpty && geminiCommunity != 'null') {
      return geminiCommunity;
    }
    return null;
  }

  static List<Map<String, dynamic>> _decomposeSubtasks({
    required String rawTranscript,
    required dynamic geminiSubtasks,
    required String? defaultDueDate,
    required List<String> log,
  }) {
    final List<Map<String, dynamic>> result = [];
    final Set<String> seen = {};

    // 1. Process Gemini subtasks
    if (geminiSubtasks is List) {
      for (final item in geminiSubtasks) {
        String title = '';
        String? dueDate;
        bool completed = false;

        if (item is Map) {
          title = (item['title'] ?? item['name'] ?? '').toString().trim();
          dueDate = item['due_date']?.toString();
          completed = item['completed'] == true;
        } else if (item is String) {
          title = item.trim();
        }

        title = _cleanSubtaskString(title);
        if (title.isNotEmpty && !seen.contains(title.toLowerCase())) {
          seen.add(title.toLowerCase());
          result.add({
            'title': title,
            'due_date': dueDate ?? defaultDueDate,
            'completed': completed,
          });
        }
      }
    }

    // 2. Scan rawTranscript for sequential clauses ("first ..., then ..., also ..., finally ...")
    final stepSplitter = RegExp(
      r'(?:,\s*)?(?:\b(?:first|1st|second|2nd|third|3rd|then|also|finally|after that|next|step\s*\d+)[:\s]+)',
      caseSensitive: false,
    );
    final parts = rawTranscript.split(stepSplitter);
    if (parts.length > 1) {
      for (final p in parts) {
        final cleaned = _cleanSubtaskString(p);
        if (cleaned.length > 2 && !seen.contains(cleaned.toLowerCase())) {
          seen.add(cleaned.toLowerCase());
          result.add({
            'title': cleaned,
            'due_date': defaultDueDate,
            'completed': false,
          });
          log.add('Extracted sequential subtask from speech: "$cleaned"');
        }
      }
    }

    return result;
  }

  static String _cleanSubtaskString(String s) {
    var clean = s
        .replaceAll(RegExp(r'^\s*[-*•\d+.)]+\s*'), '')
        .replaceAll(RegExp(r'[,;.]+$'), '')
        .replaceAll(RegExp(r'^(?:then|also|and|make sure to|ensure to)\s+', caseSensitive: false), '')
        .trim();
    if (clean.isNotEmpty) {
      clean = clean[0].toUpperCase() + clean.substring(1);
    }
    return clean;
  }

  static Map<String, dynamic> _buildTaskMap({
    required String title,
    required String? description,
    required String? dueDate,
    required String priority,
    required String? assignee,
    required String? communityId,
    required List<Map<String, dynamic>> subtasks,
  }) {
    return {
      'title': title,
      'description': description,
      'due_date': dueDate,
      'priority': priority,
      'assignee': assignee,
      'community_id': communityId,
      'subtasks': subtasks,
    };
  }
}
