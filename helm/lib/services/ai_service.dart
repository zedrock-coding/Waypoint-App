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
Act as a JSON data extractor for a task management app named Helm.
Current Date/Time: ${now.toIso8601String()}

Available Communities: ${jsonEncode(availableCommunities)}
Available Members: ${jsonEncode(availableMembers)}

User Input: "$userInput"

Extract task details and output ONLY valid JSON matching this schema:
{
  "title": "String (Core task description)",
  "due_date": "ISO 8601 String or null (calculated from relative time)",
  "priority": "String (HIGH, MEDIUM, LOW) default is MEDIUM",
  "community_id": "String (UUID of the community if mentioned, otherwise null)",
  "assignee_id": "String (UUID of the member if mentioned, otherwise null)"
}

IMPORTANT: Do not include any markdown formatting or extra text. Output the raw JSON string only.
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
