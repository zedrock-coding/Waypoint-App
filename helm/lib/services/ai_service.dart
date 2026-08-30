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
    final systemInstruction = '''
Act as an expert data extraction engine for Helm, a team task manager.
Your goal is to parse user natural language into a structured JSON object.

CURRENT CONTEXT:
- Reference Time: ${now.toIso8601String()} (Local)
- Available Communities: ${jsonEncode(availableCommunities)}
- Available Members: ${jsonEncode(availableMembers)}

EXTRACTION RULES:
1. **Title**: Summarize the core action. (e.g., "Buy milk")
2. **Due Date**: 
   - Parse relative terms based on the Reference Time above.
   - "today" -> same date as Reference Time.
   - "tomorrow" -> Reference Time + 1 day.
   - "next Friday" -> Find the date of the upcoming Friday.
   - Output MUST be a valid ISO 8601 string (e.g., "2024-08-29T23:59:59Z"). If no date is mentioned, use null.
3. **Priority**: Map to "HIGH", "MEDIUM", or "LOW". Default is "MEDIUM".
4. **Community ID**: Match mentioned community names to the provided UUIDs.
5. **Assignee ID**: Match mentioned names or "me" to the member UUIDs.

OUTPUT FORMAT:
Return ONLY a raw JSON object. Use valid ISO 8601 strings for dates (YYYY-MM-DDTHH:MM:SSZ).
If the user says "at 5pm tomorrow", calculate the exact timestamp based on the Reference Time.

SCHEMA:
{
  "title": "String",
  "due_date": "ISO8601 String or null",
  "priority": "HIGH | MEDIUM | LOW",
  "community_id": "UUID String or null",
  "assignee_id": "UUID String or null"
}
''';

    try {
      final response = await _executeWithRetry(() => _model.generateContent([
        Content.text(systemInstruction),
      ]));

      final text = response.text;
      if (text == null) return null;

      // Manually strip markdown if the AI includes it
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AiService Error: $e');
      rethrow;
    }
  }
}
