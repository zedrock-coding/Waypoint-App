import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'needle_engine.dart';

class AiService {
  late final GenerativeModel _model;
  final NeedleEngine _needleEngine;

  NeedleEngine get needleEngine => _needleEngine;

  AiService({NeedleEngine? needleEngine})
      : _needleEngine = needleEngine ?? CactusNeedleEngine() {
    _needleEngine.initialize();

    // Priority: 1. String.fromEnvironment (Compile-time) 2. flutter_dotenv (Runtime asset)
    final String envKey = const String.fromEnvironment('GEMINI_API_KEY');
    final String? dotEnvKey = dotenv.isInitialized ? dotenv.env['GEMINI_API_KEY'] : null;
    
    final apiKey = envKey.isNotEmpty ? envKey : (dotEnvKey ?? '');

    if (apiKey.isEmpty) {
      debugPrint('AiService: GEMINI_API_KEY not found in environment or .env file!');
    }

    _model = GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.system('''
Act as an expert data extraction engine for Helm, a team task manager.
Your goal is to parse user natural language into a structured JSON object.

EXTRACTION RULES:
1. **Title**: Extract a concise, actionable task title (maximum 5-7 words). You must completely rephrase the intent and NEVER just repeat the user's raw prompt.
2. **Description**: Interpret the command. If long, provide a concise summary. If short, expand it into a clear, detailed task description. Do not just copy the raw input.
3. **Due Date**: 
   - CRITICAL: Mathematically calculate exact target date based on Reference Time and Current Weekday.
   - "today" -> Reference Time date.
   - "tomorrow" -> Reference Time + 1 day.
   - "X days later" -> Add X days to Reference Time.
   - "next [Day]" -> Calculate exact date for that upcoming day.
   - Output MUST be formatted as simple date string: YYYY-MM-DD (e.g., "2026-09-03"). Do NOT include time or 'Z'. If no date mentioned, use null.
4. **Priority**: Map to "HIGH", "MEDIUM", or "LOW". Default is "MEDIUM".
5. **Community ID**: Match mentioned community names to the provided UUIDs. Use null if no match is found.
6. **Assignee ID**: Match mentioned names or "me" to the member UUIDs. Use null if no match is found.

OUTPUT FORMAT:
Return ONLY a raw JSON object. Do not wrap it in markdown. Do not include any explanations.

CONVERSATIONAL CLARIFICATION:
If the user's command is missing important actionable details (e.g., they say "remind me to prepare presentation" but give no due date/time, or "add task for the client" without clear title or deadline), engage in a natural conversation:
- Set "clarification_needed" to true.
- Set "clarification_message" to a concise, friendly question asking specifically for the missing detail (e.g., "When should this presentation be ready?", "What is the deadline for this task?").
- Retain whatever details the user already specified in the JSON schema fields.
- When an Existing Task Draft or Conversation History is provided, merge new voice answers directly into the draft.

SCHEMA:
{
  "title": "String",
  "description": "String or null",
  "due_date": "ISO8601 String or null",
  "priority": "HIGH | MEDIUM | LOW",
  "community_id": "UUID String or null",
  "assignee_id": "UUID String or null",
  "clarification_needed": Boolean,
  "clarification_message": "String or null"
}
'''),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<GenerateContentResponse> _executeWithRetry(
    Future<GenerateContentResponse> Function() request, {
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    while (true) {
      try {
        return await request();
      } on GenerativeAIException catch (e) {
        if (e.message.contains('429') && retryCount < maxRetries) {
          retryCount++;
          final delay = Duration(seconds: 1 << retryCount); 
          debugPrint('AiService: Rate limited (429). Retrying in ${delay.inSeconds}s... ($retryCount/$maxRetries)');
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
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
      final response = await _executeWithRetry(() => _model.generateContent([
        Content.text(prompt)
      ]));

      final text = response.text;
      if (text == null) return null;

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
      final response = await _executeWithRetry(() => _model.generateContent([
        Content.data('audio/wav', audioBytes),
        Content.text(prompt),
      ]));

      final text = response.text;
      if (text == null) return null;

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
      final response = await _executeWithRetry(() => _model.generateContent([
        Content.text(prompt)
      ]));

      final text = response.text;
      List<String> hints = [];
      if (text != null) {
        final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final List<dynamic> parsed = jsonDecode(cleanJson);
        hints = parsed.map((e) => e.toString()).toList();
      }

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
