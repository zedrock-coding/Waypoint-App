import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  late final GenerativeModel _model;

  AiService() {
    // Priority: 1. String.fromEnvironment (Compile-time) 2. flutter_dotenv (Runtime asset)
    final String envKey = const String.fromEnvironment('GEMINI_API_KEY');
    final String? dotEnvKey = dotenv.env['GEMINI_API_KEY'];
    
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
   - CRITICAL: Mathematically calculate exact dates.
   - "today" -> Use Reference Time.
   - "tomorrow" -> Reference Time + 1 day.
   - "X days later" -> Add exactly X days to Reference Time. Example: If Reference is 2026-08-30 and input is "4 days later", output 2026-09-03T23:59:59Z.
   - Output MUST be a valid ISO 8601 string. If no date mentioned, use null.
4. **Priority**: Map to "HIGH", "MEDIUM", or "LOW". Default is "MEDIUM".
5. **Community ID**: Match mentioned community names to the provided UUIDs. Use null if no match is found.
6. **Assignee ID**: Match mentioned names or "me" to the member UUIDs. Use null if no match is found.

OUTPUT FORMAT:
Return ONLY a raw JSON object. Do not wrap it in markdown. Do not include any explanations.
If the input lacks enough context to form a task (e.g., "do the thing", "hello"), set "clarification_needed" to true and provide a question in "clarification_message".

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
}
