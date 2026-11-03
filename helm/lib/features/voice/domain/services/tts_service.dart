// lib/features/voice/domain/services/tts_service.dart

abstract class ITextToSpeechService {
  Future<void> initialize();
  Future<void> speak(String text);
  Future<void> stop();
  void dispose();
}

