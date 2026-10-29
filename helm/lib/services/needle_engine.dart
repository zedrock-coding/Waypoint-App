import 'package:flutter/foundation.dart';

/// Abstract contract for the on-device fallback extractor.
abstract class NeedleEngine {
  Future<bool> initialize();
  bool get isReady;

  /// Transcribes raw audio locally when offline.
  ///
  /// No on-device ASR model ships with Helm, so the implementation returns
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
    String? dueDateStr = templateContext?['due_date'];
    String priorityStr = templateContext?['priority'] ?? 'MEDIUM';
    String? communityId = templateContext?['community_id'];
    String? assigneeId = templateContext?['assignee_id'];

    final lower = cleanInput.toLowerCase();

    // 2. Rule-based priority extraction
    if (templateContext?['priority'] == null) {
      if (lower.contains('urgent') || lower.contains('high priority') || lower.contains('asap')) {
        priorityStr = 'HIGH';
      } else if (lower.contains('low priority') || lower.contains('when possible') || lower.contains('minor')) {
        priorityStr = 'LOW';
      } else {
        priorityStr = 'MEDIUM';
      }
    }

    // 3. Rule-based date parsing
    if (dueDateStr == null) {
      final now = DateTime.now();
      if (lower.contains('today')) {
        dueDateStr = _formatDate(now);
      } else if (lower.contains('tomorrow')) {
        dueDateStr = _formatDate(now.add(const Duration(days: 1)));
      } else {
        final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        for (int i = 0; i < days.length; i++) {
          if (lower.contains(days[i])) {
            int targetWeekday = i + 1;
            int daysToAdd = (targetWeekday - now.weekday + 7) % 7;
            if (daysToAdd == 0) daysToAdd = 7;
            dueDateStr = _formatDate(now.add(Duration(days: daysToAdd)));
            break;
          }
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

    // 5. Title & Description Cleanup
    if (title.isEmpty) {
      // Rephrase clean title
      var candidate = cleanInput
          .replaceAll(RegExp(r'\b(urgent|high priority|low priority|asap|today|tomorrow)\b', caseSensitive: false), '')
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

    // Fallback template items derived from title
    return [
      'Scope requirements for $title',
      'Implement core solution',
      'Verify and mark complete',
    ];
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
