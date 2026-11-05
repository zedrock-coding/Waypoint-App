// test/features/voice/voice_call_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/voice/domain/controllers/voice_session_controller.dart';

void main() {
  group('Call-Style Hands-Free Voice Session Tests', () {
    test('Automatically transitions from AgentSpeaking back to UserListening on disambiguation', () async {
      final controller = VoiceSessionController();

      controller.startCall();
      expect(controller.status, VoiceSessionStatus.userListening);

      // User finishes speaking first chunk (missing due date)
      await controller.completeUserSpeechTurn();
      expect(controller.status, VoiceSessionStatus.processing);

      // System speaks clarification question
      controller.playAgentResponse('prompt.wav', isDisambiguation: true);

      // Auto-reconnect triggered: mic is active again, timer is reset
      expect(controller.status, VoiceSessionStatus.userListening);
      expect(controller.remaining.inSeconds, 30);

      controller.endCall();
      expect(controller.status, VoiceSessionStatus.idle);
    });
  });
}

