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
      : _needleEngine = needleEngine ?? CactusNeedleEngine() {
    _needleEngine.initialize();
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
  }) async {
    final body = <String, dynamic>{
      'prompt': prompt,
      if (audioBytes != null) ...{
        'audio_base64': base64Encode(audioBytes),
        'audio_mime_type': 'audio/wav',
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

    final prompt = '''
CURRENT CONTEXT:
- Reference Time: ${now.toIso8601String()} (Local)
- Current Weekday: $currentWeekday
- Available Communities: ${jsonEncode(availableCommunities)}
- Available Members: ${jsonEncode(availableMembers)}

User Input: "$userInput"
''';

    try {
      final text = await _generate(prompt: prompt);
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AiService Error: $e');
      rethrow;
    }
  }

  /// Two-Tier Hybrid parsing: Fast on-device Needle 3 extraction + Cloud de-jumbling
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

    // Fast Path: Direct simple commands run on edge Needle engine
    if (!forceCloud && isSimple && _needleEngine.isReady) {
      try {
        final localResult = await _needleEngine.extractTask(
          input: clean,
          availableCommunities: availableCommunities,
          availableMembers: availableMembers,
        );
        if (localResult != null) return localResult;
      } catch (e) {
        debugPrint('NeedleEngine Fast Path error: $e');
      }
    }

    // Cloud Tier: Gemini unjumbles complex words into structured template
    try {
      final cloudTemplate = await parseTaskCommand(
        userInput: clean,
        availableCommunities: availableCommunities,
        availableMembers: availableMembers,
      );

      // Pass cloud blueprint through Needle Engine for deterministic schema enforcement
      return await _needleEngine.extractTask(
        input: clean,
        templateContext: cloudTemplate,
        availableCommunities: availableCommunities,
        availableMembers: availableMembers,
      );
    } catch (e) {
      debugPrint('Cloud Tier Fallback to NeedleEngine: $e');
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
1. If an Existing Task Draft is provided, integrate and merge the user's voice reply into that draft.
2. If essential details are still missing (such as due date, clarity of what needs doing), set "clarification_needed": true and generate "clarification_message" with a short, conversational question.
3. If enough information is provided to make an actionable task, set "clarification_needed": false and return the complete task JSON.
''';

    try {
      final text = await _generate(prompt: prompt, audioBytes: audioBytes);
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> cloudTemplate = jsonDecode(cleanJson);

      // Enforce grammar constraints via NeedleEngine
      return await _needleEngine.extractTask(
        input: cloudTemplate['title'] ?? (currentDraft?['title'] ?? 'Voice Task'),
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
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> parsed = jsonDecode(cleanJson);
      final hints = parsed.map((e) => e.toString()).toList();

      // Needle Engine validates and expands subtasks
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
