import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waypoint/ai_voice_overlay.dart';
import 'package:waypoint/models/unified_task.dart';
import 'package:waypoint/providers/task_provider.dart';
import 'package:waypoint/services/ai_service.dart';

class MockTaskProvider extends ChangeNotifier implements TaskProvider {
  String? addedTitle;
  DateTime? addedDueAt;
  Priority? addedPriority;
  List<Map<String, dynamic>> addedSubtasks = [];

  @override
  Future<String> addTask({
    required String title,
    String? description,
    String? communityId,
    List<String> categoryIds = const [],
    List<String> assignees = const [],
    List<Map<String, dynamic>> subtasks = const [],
    Priority priority = Priority.medium,
    Status status = Status.toDo,
    bool isLocalOnly = false,
    DateTime? dueAt,
  }) async {
    addedTitle = title;
    addedDueAt = dueAt;
    addedPriority = priority;
    addedSubtasks = subtasks;
    return 'mock-task-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAiService extends AiService {
  Map<String, dynamic>? simulatedResult;

  @override
  Future<Map<String, dynamic>?> parseHybridCommand({
    required String userInput,
    required List<Map<String, dynamic>> availableCommunities,
    required List<Map<String, dynamic>> availableMembers,
    bool forceCloud = false,
  }) async {
    return simulatedResult ??
        {
          'transcript': userInput,
          'title': userInput,
          'due_date': '2026-11-11T17:00:00',
          'priority': 'HIGH',
          'subtasks': ['Step 1 test'],
          'clarification_needed': false,
        };
  }

  @override
  Future<Map<String, dynamic>?> parseVoiceCommand({
    required Uint8List audioBytes,
    required List<Map<String, dynamic>> availableCommunities,
    required List<Map<String, dynamic>> availableMembers,
    Map<String, dynamic>? currentDraft,
    List<Map<String, String>> conversationHistory = const [],
    String? audioMimeType,
  }) async {
    return simulatedResult ??
        {
          'transcript': 'please create a task saying Deploy auth hotfix tomorrow at 5pm',
          'title': 'Deploy auth hotfix',
          'due_date': '2026-11-11T17:00:00',
          'priority': 'HIGH',
          'subtasks': ['Step 1 test'],
          'clarification_needed': false,
        };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AIVoiceOverlay mounts cleanly and displays audio interface', (tester) async {
    final aiService = FakeAiService();
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

    expect(find.byType(AIVoiceOverlay), findsOneWidget);

    final hasListeningText = find.text('Waypoint is listening...').evaluate().isNotEmpty;
    final hasMicPermissionText = find.textContaining('Microphone permission').evaluate().isNotEmpty;
    expect(hasListeningText || hasMicPermissionText, isTrue);

    if (hasListeningText) {
      expect(find.textContaining('Done Speaking'), findsOneWidget);
    }
  });

  testWidgets('Direct Integration: finishRecordingAndProcess reconciles verified task and saves to TaskProvider', (tester) async {
    final aiService = FakeAiService();
    aiService.simulatedResult = {
      'transcript': 'please create a task saying Deploy auth hotfix tomorrow at 5pm',
      'title': 'create a task saying Deploy auth hotfix',
      'due_date': '2026-11-11T17:00:00',
      'priority': 'HIGH',
      'subtasks': ['Review code', 'Deploy staging'],
      'clarification_needed': false,
    };

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

    final overlayState = tester.state<AIVoiceOverlayState>(find.byType(AIVoiceOverlay));

    // Execute active _finishRecordingAndProcess with simulated voice transcript
    await overlayState.finishRecordingAndProcess(
      simulatedTranscript: 'please create a task saying Deploy auth hotfix tomorrow at 5pm',
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify Needle AI reconciled and stripped meta-framing before committing
    expect(taskProvider.addedTitle, 'Deploy auth hotfix');
    expect(taskProvider.addedPriority, Priority.high);
    expect(taskProvider.addedSubtasks.length, 2);
  });

  testWidgets('Direct Integration: finishRecordingAndProcess triggers clarification turn when intent is ambiguous', (tester) async {
    final aiService = FakeAiService();
    aiService.simulatedResult = {
      'transcript': 'remind me to prepare presentation',
      'title': 'Prepare presentation',
      'due_date': null,
      'clarification_needed': true,
      'clarification_message': 'When would you like this presentation completed?',
    };

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

    final overlayState = tester.state<AIVoiceOverlayState>(find.byType(AIVoiceOverlay));

    await overlayState.finishRecordingAndProcess(
      simulatedTranscript: 'remind me to prepare presentation',
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify task was not prematurely saved and clarification prompt was engaged
    expect(taskProvider.addedTitle, isNull);
    expect(find.textContaining('When would you like this presentation completed?'), findsOneWidget);
  });
}
