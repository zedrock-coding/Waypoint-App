import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'needle_engine.dart';

/// Raised when the AI backend cannot service a request.
///
/// Callers already fall back to the on-device [NeedleEngine] heuristic, so the
/// message is only surfaced when nothing else can answer.
class AiException implements Exception {
  const AiException(this.message, {this.rateLimited = false});

  final String message;
  final bool rateLimited;

  @override
  String toString() => message;
}

class AiService {
  final NeedleEngine _needleEngine;

  NeedleEngine get needleEngine => _needleEngine;

  AiService({NeedleEngine? needleEngine})
      : _needleEngine = needleEngine ?? LocalHeuristicParser() {
    _needleEngine.initialize();
  }

  /// Safely parses an AI due_date (and optional due_time) into a [DateTime].
  ///
  /// If the string contains an explicit time component (e.g. `2026-10-31T17:00:00`),
  /// that exact local time is preserved. If only a date is provided (e.g. `2026-10-31`),
  /// it defaults to midday (12:00:00).
  static DateTime? parseAiDueDate(dynamic dueDateVal, [dynamic dueTimeVal]) {
    if (dueDateVal == null) return null;
    final str = dueDateVal.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;

    final parsed = DateTime.tryParse(str);
    if (parsed == null) return null;

    final local = parsed.isUtc ? parsed.toLocal() : parsed;

    // Check if the input string contains an explicit time component
    final hasExplicitTime = RegExp(r'[T\s]\d{1,2}:\d{2}').hasMatch(str);

    int hour = hasExplicitTime ? local.hour : 12;
    int minute = hasExplicitTime ? local.minute : 0;
    int second = hasExplicitTime ? local.second : 0;

    if (dueTimeVal != null && dueTimeVal.toString().trim().isNotEmpty) {
      final timeStr = dueTimeVal.toString().trim();
      final matchAmPm = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', caseSensitive: false).firstMatch(timeStr);
      if (matchAmPm != null) {
        int h = int.parse(matchAmPm.group(1)!);
        int m = matchAmPm.group(2) != null ? int.parse(matchAmPm.group(2)!) : 0;
        final isPm = matchAmPm.group(3)!.toLowerCase() == 'pm';
        if (isPm && h < 12) h += 12;
        if (!isPm && h == 12) h = 0;
        hour = h;
        minute = m;
        second = 0;
      } else {
        final match24 = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeStr);
        if (match24 != null) {
          hour = int.parse(match24.group(1)!);
          minute = int.parse(match24.group(2)!);
          second = 0;
        }
      }
    }

    return DateTime(local.year, local.month, local.day, hour, minute, second);
  }

  /// Extracts structured JSON object from AI response text, stripping markdown fences or preamble.
  static Map<String, dynamic> _cleanAndDecodeJson(String text) {
    var clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      final direct = jsonDecode(clean);
      if (direct is Map<String, dynamic>) return direct;
      if (direct is Map) return Map<String, dynamic>.from(direct);
    } catch (_) {
      // Preamble or markdown wrapping: fallback to extracting outermost braces
    }
    final firstBrace = clean.indexOf('{');
    final lastBrace = clean.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace >= firstBrace) {
      clean = clean.substring(firstBrace, lastBrace + 1);
    }
    return jsonDecode(clean) as Map<String, dynamic>;
  }

  /// Extracts structured subtasks list from AI response text.
  /// Handles both pure JSON arrays, JSON objects with 'subtasks', and text with brackets.
  static List<String> extractSubtasksFromAiResponse(String text) {
    final clean = text.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      final decoded = jsonDecode(clean);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (decoded is Map) {
        final subtasks = decoded['subtasks'];
        if (subtasks is List) {
          return subtasks
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        for (final val in decoded.values) {
          if (val is List) {
            return val
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (_) {
      // Direct decode failed (preamble or truncated JSON). Try regex array/object search.
      final arrayRegex = RegExp(r'\[[\s\S]*?\]');
      for (final match in arrayRegex.allMatches(clean)) {
        try {
          final decoded = jsonDecode(match.group(0)!);
          if (decoded is List) {
            return decoded
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }

      final objectRegex = RegExp(r'\{[\s\S]*?\}');
      for (final match in objectRegex.allMatches(clean)) {
        try {
          final decoded = jsonDecode(match.group(0)!);
          if (decoded is Map && decoded['subtasks'] is List) {
            return (decoded['subtasks'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
    }
    return [];
  }

  static String detectMimeType(Uint8List bytes) {
    if (bytes.length >= 8) {
      if (bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70) {
        return 'audio/mp4';
      }
      if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        return 'audio/mp3';
      }
      if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
        return 'audio/mp3';
      }
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        return 'audio/wav';
      }
    }
    return 'audio/wav';
  }

  /// Single network entry point.
  ///
  /// The Gemini credential lives only in the `ai` Edge Function's environment.
  /// The client never holds one, so no API key can be extracted from a web
  /// bundle or an APK. The fixed system instruction (schema, extraction rules,
  /// `gemini-3.5-flash-lite`) also lives server-side, next to the key it
  /// protects.
  Future<String> _generate({
    required String prompt,
    Uint8List? audioBytes,
    String? audioMimeType,
  }) async {
    String? audioBase64;
    if (audioBytes != null) {
      audioBase64 = audioBytes.length > 50000
          ? await compute(base64Encode, audioBytes)
          : base64Encode(audioBytes);
    }

    final body = <String, dynamic>{
      'prompt': prompt,
      if (audioBase64 != null) ...{
        'audio_base64': audioBase64,
        'audio_mime_type': audioMimeType ?? detectMimeType(audioBytes!),
      },
    };

    FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        AppConfig.aiFunctionName,
        body: body,
      );
    } on FunctionException catch (e) {
      throw _mapFunctionError(e);
    } catch (e) {
      debugPrint('AiService network error: $e');
      throw const AiException(
        'Could not reach the AI service. Check your connection and try again.',
      );
    }

    final data = response.data;
    if (data is Map && data['text'] is String) {
      final text = (data['text'] as String).trim();
      if (text.isNotEmpty) return text;
    }
    throw const AiException('The AI service returned an empty response.');
  }

  AiException _mapFunctionError(FunctionException e) {
    String? serverMessage;
    final details = e.details;
    if (details is Map) {
      final raw = details['error'] ?? details['message'];
      if (raw is String && raw.trim().isNotEmpty) serverMessage = raw.trim();
    }

    if (e.status == 429) {
      return AiException(
        serverMessage ?? 'Daily AI limit reached. Try again tomorrow.',
        rateLimited: true,
      );
    }
    if (e.status == 401 || e.status == 403) {
      return const AiException('Sign in to use AI commands.');
    }
    if (e.status == 413) {
      return const AiException('That recording is too long. Keep it under 30 seconds.');
    }
    return AiException(serverMessage ?? 'The AI service is unavailable right now.');
  }

  /// Original text parser with fallback logic
  Future<Map<String, dynamic>?> parseTaskCommand({
    required String userInput,
    required List<Map<String, dynamic>> availableCommunities,
    required List<Map<String, dynamic>> availableMembers,
  }) async {
    final now = DateTime.now();
    final List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentWeekday = weekdays[now.weekday - 1];

    final tzName = now.timeZoneName;
    final tzOffset = now.timeZoneOffset.inHours;

    final prompt = '''
CONTEXT HEADER:
{
  "client_timestamp": "${now.toIso8601String()}",
  "client_timezone": "$tzName",
  "first_day_of_week": 1
}

CURRENT CONTEXT:
- Reference Time: ${now.toIso8601String()} (Timezone: $tzName, UTC${tzOffset >= 0 ? '+' : ''}$tzOffset)
- Current Weekday: $currentWeekday
- Available Communities: ${jsonEncode(availableCommunities)}
- Available Members: ${jsonEncode(availableMembers)}

User Input: "$userInput"
''';

    try {
      final text = await _generate(prompt: prompt);
      return _cleanAndDecodeJson(text);
    } catch (e) {
      debugPrint('AiService Error: $e');
      rethrow;
    }
  }

  /// Two-tier hybrid parsing: fast local heuristic first, cloud de-jumbling second.
  Future<Map<String, dynamic>?> parseHybridCommand({
    required String userInput,
    required List<Map<String, dynamic>> availableCommunities,
    required List<Map<String, dynamic>> availableMembers,
    bool forceCloud = false,
  }) async {
    final clean = userInput.trim();
    if (clean.isEmpty) return null;

    final wordCount = clean.split(RegExp(r'\s+')).length;
    final isSimple = wordCount <= 8;

    // Fast path: short commands are parsed locally, no network round trip.
    if (!forceCloud && isSimple && _needleEngine.isReady) {
      try {
        final localResult = await _needleEngine.extractTask(
          input: clean,
          availableCommunities: availableCommunities,
          availableMembers: availableMembers,
        );
        if (localResult != null) return localResult;
      } catch (e) {
        debugPrint('Local parser fast-path error: $e');
      }
    }

    // Cloud Tier: Gemini unjumbles complex words into structured template
    try {
      final cloudTemplate = await parseTaskCommand(
        userInput: clean,
        availableCommunities: availableCommunities,
        availableMembers: availableMembers,
      );

      // Normalise the cloud answer through the local parser so the schema is fixed.
      return await _needleEngine.extractTask(
        input: clean,
        templateContext: cloudTemplate,
        availableCommunities: availableCommunities,
        availableMembers: availableMembers,
      );
    } catch (e) {
      debugPrint('Cloud tier failed, falling back to the local parser: $e');
      return await _needleEngine.extractTask(
        input: clean,
        availableCommunities: availableCommunities,
        availableMembers: availableMembers,
      );
    }
  }

  /// Direct Multimodal Audio Ingestion with conversational multi-turn slot refinement
  Future<Map<String, dynamic>?> parseVoiceCommand({
    required Uint8List audioBytes,
    required List<Map<String, dynamic>> availableCommunities,
    required List<Map<String, dynamic>> availableMembers,
    Map<String, dynamic>? currentDraft,
    List<Map<String, String>> conversationHistory = const [],
    String? audioMimeType,
  }) async {
    final now = DateTime.now();
    final List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentWeekday = weekdays[now.weekday - 1];

    final historySnippet = conversationHistory.isEmpty
        ? 'None'
        : conversationHistory.map((h) => '${h['role']}: ${h['content']}').join('\n');

    final draftSnippet = currentDraft == null
        ? 'None'
        : jsonEncode(currentDraft);

    final prompt = '''
CONTEXT HEADER:
{
  "client_timestamp": "${now.toIso8601String()}",
  "client_timezone": "${now.timeZoneName}",
  "first_day_of_week": 1
}

Listen to the user speaking and extract or refine the task intent.
De-jumble any rambling, vocal pauses, or self-corrections in the audio.

CURRENT CONTEXT:
- Reference Time: ${now.toIso8601String()} (Local)
- Current Weekday: $currentWeekday
- Available Communities: ${jsonEncode(availableCommunities)}
- Available Members: ${jsonEncode(availableMembers)}
- Existing Task Draft: $draftSnippet
- Conversation History:
$historySnippet

INSTRUCTIONS:
1. Provide a verbatim "transcript" of the user's spoken words.
2. If an Existing Task Draft is provided, integrate and merge the user's voice reply into that draft.
3. If essential details are still missing (such as due date, clarity of what needs doing), set "clarification_needed": true and generate "clarification_message" with a short, conversational question.
4. If enough information is provided to make an actionable task, set "clarification_needed": false and return the complete task JSON.
''';

    try {
      final text = await _generate(
        prompt: prompt,
        audioBytes: audioBytes,
        audioMimeType: audioMimeType,
      );
      final Map<String, dynamic> cloudTemplate = _cleanAndDecodeJson(text);

      // Normalise the cloud answer through the local parser
      return await _needleEngine.extractTask(
        input: cloudTemplate['transcript'] ?? cloudTemplate['title'] ?? (currentDraft?['title'] ?? 'Voice Task'),
        templateContext: cloudTemplate,
        availableCommunities: availableCommunities,
        availableMembers: availableMembers,
      );
    } catch (e) {
      debugPrint('Multimodal Voice Command Error: $e');
      rethrow;
    }
  }

  Future<List<String>> generateSubtasks({
    required String title,
    required String description,
  }) async {
    final prompt = '''
Analyze task title and description. Break down into 3-5 concise, actionable subtasks.
Output ONLY raw JSON string array. No markdown.

Task Title: "$title"
Task Description: "$description"

SCHEMA:
[
  "Subtask 1",
  "Subtask 2"
]
''';

    try {
      final text = await _generate(prompt: prompt);
      final hints = extractSubtasksFromAiResponse(text);

      // Local parser validates and expands subtasks
      return await _needleEngine.expandSubtasks(
        title: title,
        templateHints: hints,
      );
    } catch (e) {
      debugPrint('AiService Subtask Error: $e');
      return await _needleEngine.expandSubtasks(
        title: title,
        templateHints: [],
      );
    }
  }
}
