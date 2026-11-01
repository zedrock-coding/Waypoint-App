import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waypoint/ai_voice_overlay.dart';
import 'package:waypoint/providers/task_provider.dart';
import 'package:waypoint/services/ai_service.dart';

class MockTaskProvider extends ChangeNotifier implements TaskProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AIVoiceOverlay mounts cleanly and displays audio interface', (tester) async {
    final aiService = AiService();
    final taskProvider = MockTaskProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiService>.value(value: aiService),
          ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AIVoiceOverlay(),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify overlay renders without crashing
    expect(find.byType(AIVoiceOverlay), findsOneWidget);

    // Either listening state with controls or permission fallback is rendered gracefully
    final hasListeningText = find.text('Waypoint is listening...').evaluate().isNotEmpty;
    final hasMicPermissionText = find.textContaining('Microphone permission').evaluate().isNotEmpty;
    expect(hasListeningText || hasMicPermissionText, isTrue);

    if (hasListeningText) {
      expect(find.textContaining('Done Speaking'), findsOneWidget);
    }
  });
}
