import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/services/task_extraction_parser.dart';
import 'package:waypoint/features/voice/data/sherpa_tts_service.dart';
import 'package:waypoint/features/voice/domain/controllers/voice_session_controller.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel ttsChannel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'setSpeechRate' ||
          methodCall.method == 'setVolume' ||
          methodCall.method == 'setPitch' ||
          methodCall.method == 'awaitSpeakCompletion' ||
          methodCall.method == 'speak' ||
          methodCall.method == 'stop' ||
          methodCall.method == 'isLanguageAvailable' ||
          methodCall.method == 'setLanguage') {
        return 1;
      }
      return null;
    });
  });

  group('Voice Audio Feedback and Disambiguation Tests', () {
    test('SherpaTtsService can be instantiated and initialized without crashing', () async {
      final tts = SherpaTtsService();
      await tts.initialize();
      expect(tts.isInitialized, isTrue);
      expect(tts.isPlaying, isFalse);

      await tts.speak('When would you like this scheduled?');
      expect(tts.isPlaying, isFalse);
      tts.dispose();
    });

    test('Missing fields trigger disambiguation prompt and audio playback', () async {
      final spokenTexts = <String>[];
      final mockTts = _TestSpyTts((text) => spokenTexts.add(text));

      final parser = TaskExtractionParser(
        anchor: DateTime.parse('2026-11-06T10:00:00+05:30'),
      );
      final controller = VoiceSessionController(
        parser: parser,
        ttsService: mockTts,
      );

      controller.startCall();
      expect(controller.state, VoiceSessionState.listening);

      // Speak command without due date/time
      await controller.processUserInput('Remind me to call the client');

      // Verify mid stop and disambiguation audio feedback
      expect(controller.state, VoiceSessionState.listening); // Auto resumed
      expect(controller.lastQuestion, isNotNull);
      expect(spokenTexts.length, equals(1));
      expect(spokenTexts.first, contains('When would you like'));

      // Provide the missing schedule and priority
      await controller.processUserInput('make it high priority and due today evening');

      // Verify completion audio feedback
      expect(controller.isTaskCreated, isTrue);
      expect(spokenTexts.length, equals(2));
      expect(spokenTexts.last, contains('Created task: call the client'));

      controller.dispose();
    });
  });
}

class _TestSpyTts implements ITextToSpeechService {
  final void Function(String) onSpeak;
  _TestSpyTts(this.onSpeak);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    onSpeak(text);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
