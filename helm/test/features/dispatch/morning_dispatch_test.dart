// test/features/dispatch/morning_dispatch_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:waypoint/core/services/app_initialization_service.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_dispatch_engine.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_morning_dispatch_service.dart';
import 'package:waypoint/features/task/domain/models/task.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';

class MockNotificationPermissionHandler implements NotificationPermissionHandler {
  PermissionStatus status;
  bool requestCalled = false;

  MockNotificationPermissionHandler({this.status = PermissionStatus.denied});

  @override
  Future<PermissionStatus> checkStatus() async => status;

  @override
  Future<PermissionStatus> requestPermission() async {
    requestCalled = true;
    status = PermissionStatus.granted;
    return status;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Needle Morning Dispatch Verification Tests', () {
    final now = DateTime(2026, 11, 5, 8, 0);

    test('Test 1: Task Matrix Aggregation: 2 overdue/urgent, 3 medium (2 days), 5 low priority', () {
      final mockTasks = [
        // 2 Overdue / Urgent tasks
        Task(
          id: 'crit-1',
          title: 'Resolve critical auth outage',
          dueDate: now.subtract(const Duration(hours: 3)),
          priority: TaskPriority.urgent,
        ),
        Task(
          id: 'crit-2',
          title: 'Submit quarterly budget proposal',
          dueDate: now.subtract(const Duration(days: 1)),
          priority: TaskPriority.high,
        ),

        // 3 Medium tasks due in 2 days
        Task(
          id: 'med-1',
          title: 'Review pull request for backend migration',
          dueDate: now.add(const Duration(days: 2)),
          priority: TaskPriority.medium,
        ),
        Task(
          id: 'med-2',
          title: 'Update Supabase sync schema',
          dueDate: now.add(const Duration(days: 2)),
          priority: TaskPriority.medium,
        ),
        Task(
          id: 'med-3',
          title: 'Prepare demo slide deck',
          dueDate: now.add(const Duration(days: 2)),
          priority: TaskPriority.medium,
        ),

        // 5 Low priority tasks
        Task(id: 'low-1', title: 'Clean up unused branches', priority: TaskPriority.low),
        Task(id: 'low-2', title: 'Update profile avatar', priority: TaskPriority.low),
        Task(id: 'low-3', title: 'Archive completed Slack channels', priority: TaskPriority.low),
        Task(id: 'low-4', title: 'Read architecture tech debt article', priority: TaskPriority.low),
        Task(id: 'low-5', title: 'Tidy up download directory', priority: TaskPriority.low),
      ];

      final summary = NeedleDispatchEngine.filter(mockTasks, now);
      final script = NeedleDispatchEngine.compileBriefingScript(summary);

      expect(summary.criticalTasks.length, 2);
      expect(summary.mediumCount, 3);
      expect(summary.lowCount, 5);

      // Verify exact aggregation sentences
      expect(script, contains('You have 3 medium tasks due in the next few days.'));
      expect(script, contains('There are 5 low priority items on your horizon.'));
    });

    test('Test 2: First-Launch Permission: Mock permission status as denied and assert request() is triggered', () async {
      final mockHandler = MockNotificationPermissionHandler(status: PermissionStatus.denied);

      await AppInitializationService.init(
        customPermissionHandler: mockHandler,
        registerChannel: false,
        scheduleDispatch: false,
      );

      expect(mockHandler.requestCalled, isTrue);
    });

    test('Permission already granted does not trigger redundant request()', () async {
      final mockHandler = MockNotificationPermissionHandler(status: PermissionStatus.granted);

      await AppInitializationService.init(
        customPermissionHandler: mockHandler,
        registerChannel: false,
        scheduleDispatch: false,
      );

      expect(mockHandler.requestCalled, isFalse);
    });

    test('Calculates delay until 08:00 AM accurately', () {
      final at6AM = DateTime(2026, 11, 5, 6, 0);
      final delayMorning = NeedleMorningDispatchService.calculateInitialDelay(at6AM);
      expect(delayMorning, const Duration(hours: 2));

      final at9AM = DateTime(2026, 11, 5, 9, 0);
      final delayAfternoon = NeedleMorningDispatchService.calculateInitialDelay(at9AM);
      expect(delayAfternoon, const Duration(hours: 23));
    });

    test('Audio Briefing Execution plays compiled script via TTS', () async {
      final mockTts = MockTtsService();
      final mockTasks = [
        Task(
          id: '1',
          title: 'Review production metrics',
          dueDate: now.add(const Duration(hours: 1)),
          priority: TaskPriority.urgent,
        ),
      ];

      await NeedleMorningDispatchService.executeDailyDispatch(
        tasks: mockTasks,
        now: now,
        ttsService: mockTts,
      );

      expect(NeedleMorningDispatchService.lastGeneratedScript, isNotNull);
      expect(NeedleMorningDispatchService.lastGeneratedScript, contains('Review production metrics'));

      await NeedleMorningDispatchService.playBriefing(ttsService: mockTts);
      expect(mockTts.lastSpokenText, contains('Review production metrics'));
    });
  });
}
