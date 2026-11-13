import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waypoint/models/unified_task.dart';
import 'package:waypoint/providers/task_provider.dart';
import 'package:waypoint/services/ai_service.dart';
import 'package:waypoint/widgets/command_bar.dart';
import 'package:waypoint/ai_voice_overlay.dart';

class MockAiService extends Fake implements AiService {
  int callCount = 0;
  Map<String, dynamic>? lastPassedDraft;
  List<Map<String, String>>? lastPassedHistory;

  @override
  Future<Map<String, dynamic>?> parseVoiceCommand({
    required List<int> audioBytes,
    String? audioMimeType,
    List<Map<String, dynamic>>? availableCommunities,
    List<Map<String, dynamic>>? availableMembers,
    Map<String, dynamic>? currentDraft,
    List<Map<String, String>>? conversationHistory,
  }) async {
    callCount++;
    lastPassedDraft = currentDraft;
    lastPassedHistory = conversationHistory;

    if (callCount == 1) {
      // First turn: partial command lacking due date
      return {
        'clarification_needed': true,
        'clarification_message': 'When would you like this scheduled?',
        'title': 'Call dentist',
      };
    } else {
      // Second turn: answers the clarification
      return {
        'clarification_needed': false,
        'title': 'Call dentist',
        'due_date': '2026-11-07',
        'due_time': '14:00',
        'priority': 'high',
        'subtasks': ['Find dental clinic phone number', 'Book 2pm slot'],
      };
    }
  }

  @override
  Future<Map<String, dynamic>?> parseHybridCommand({
    required String userInput,
    List<Map<String, dynamic>>? availableCommunities,
    List<Map<String, dynamic>>? availableMembers,
    bool forceCloud = false,
  }) async {
    return {
      'clarification_needed': false,
      'title': userInput,
      'subtasks': [],
    };
  }
}

class MockTaskProvider extends ChangeNotifier implements TaskProvider {
  final List<UnifiedTask> addedTasks = [];

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
    bool isRecurring = false,
    RecurrenceRule? recurrenceRule,
    String? parentRecurringTaskId,
    DateTime? originalDueDate,
  }) async {
    addedTasks.add(UnifiedTask(
      id: 'mock_task_${addedTasks.length}',
      title: title,
      description: description ?? '',
      dateTime: DateTime.now(),
      dueDate: dueAt,
      isCompleted: false,
      status: status,
      communityId: communityId,
      categoryIds: categoryIds,
      priority: priority,
      assignees: assignees,
      isLocal: isLocalOnly,
      order: 0,
      subtasks: subtasks,
      updatedAt: DateTime.now(),
    ));
    notifyListeners();
    return 'mock_task_id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel ttsChannel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (MethodCall methodCall) async {
      return 1;
    });

    const MethodChannel recordChannel = MethodChannel('com.llfbandit.record/messages');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'hasPermission') return true;
      if (methodCall.method == 'start') return null;
      if (methodCall.method == 'stop') return null;
      return null;
    });
  });

  testWidgets('CommandBarWidget mounts with AI voice assistant trigger and command input', (tester) async {
    final aiService = MockAiService();
    final taskProvider = MockTaskProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiService>.value(value: aiService),
          ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CommandBarWidget(),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });

  testWidgets('CommandBarWidget voice tap opens AI voice overlay', (tester) async {
    final aiService = MockAiService();
    final taskProvider = MockTaskProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiService>.value(value: aiService),
          ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CommandBarWidget(),
          ),
        ),
      ),
    );

    // Tap mic button
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify it transitions to AI voice overlay
    expect(find.byType(AIVoiceOverlay), findsOneWidget);
  });
}
