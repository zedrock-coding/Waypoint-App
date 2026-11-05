// test/features/widgets/widget_payload_test.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/task/domain/models/task.dart';
import 'package:waypoint/services/widget_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetSyncService Payload & Synchronization Tests', () {
    test('1. WidgetSyncService correctly groups tasks by calendar day for the month payload', () {
      final tasks = [
        Task(
          id: '1',
          title: 'Review PR #42',
          dueDate: DateTime(2026, 11, 5, 10, 0),
          priority: TaskPriority.urgent,
        ),
        Task(
          id: '2',
          title: 'Design 4x4 Android Widget',
          dueDate: DateTime(2026, 11, 5, 14, 30),
          priority: TaskPriority.high,
        ),
        Task(
          id: '3',
          title: 'Weekly Standup',
          dueDate: DateTime(2026, 11, 6, 9, 0),
          priority: TaskPriority.medium,
        ),
      ];

      final monthPayload = WidgetSyncService.generateMonthPayload(
        tasks,
        anchor: DateTime(2026, 11, 1),
      );

      expect(monthPayload['month_title'], 'November 2026');
      expect(monthPayload['year'], 2026);
      expect(monthPayload['month'], 11);

      final days = monthPayload['days'] as Map<String, dynamic>;
      expect(days.containsKey('2026-11-05'), true);
      expect((days['2026-11-05'] as List).length, 2);

      expect(days.containsKey('2026-11-06'), true);
      expect((days['2026-11-06'] as List).length, 1);

      // Pending days indicator for calendar accent dots
      final pendingDays = monthPayload['pending_days'] as List;
      expect(pendingDays.contains('2026-11-05'), true);
      expect(pendingDays.contains('2026-11-06'), true);
    });

    test('2. WidgetSyncService sorts Day widget tasks strictly by priority hierarchy', () {
      final today = DateTime(2026, 11, 5);
      final tasks = [
        Task(
          id: '1',
          title: 'Medium priority work',
          dueDate: today,
          priority: TaskPriority.medium,
        ),
        Task(
          id: '2',
          title: 'Low priority maintenance',
          dueDate: today,
          priority: TaskPriority.low,
        ),
        Task(
          id: '3',
          title: 'Urgent hotfix',
          dueDate: today,
          priority: TaskPriority.urgent,
        ),
        Task(
          id: '4',
          title: 'High priority customer issue',
          dueDate: today,
          priority: TaskPriority.high,
        ),
      ];

      final dayPayload = WidgetSyncService.generateDayPayload(tasks, date: today);
      final dayTasks = dayPayload['tasks'] as List<Map<String, dynamic>>;

      expect(dayTasks.length, 4);
      // Strict priority hierarchy: Urgent (0) -> High (1) -> Medium (2) -> Low (3)
      expect(dayTasks[0]['priority'], 'urgent');
      expect(dayTasks[0]['title'], 'Urgent hotfix');

      expect(dayTasks[1]['priority'], 'high');
      expect(dayTasks[1]['title'], 'High priority customer issue');

      expect(dayTasks[2]['priority'], 'medium');
      expect(dayTasks[2]['title'], 'Medium priority work');

      expect(dayTasks[3]['priority'], 'low');
      expect(dayTasks[3]['title'], 'Low priority maintenance');
    });

    test('3. Updating a task locally produces a valid JSON payload readable by home_widget', () async {
      final Map<String, dynamic> savedWidgetData = {};
      final List<String> updatedWidgets = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), (MethodCall call) async {
        if (call.method == 'saveWidgetData') {
          final args = call.arguments as Map;
          savedWidgetData[args['id'] as String] = args['data'];
          return true;
        } else if (call.method == 'updateWidget') {
          final args = call.arguments as Map;
          final widgetName = (args['android'] ?? args['name'] ?? args['qualifiedAndroidName'] ?? '') as String;
          updatedWidgets.add(widgetName);
          return true;
        }
        return null;
      });

      final task = Task(
        id: 'task_widget_test_1',
        title: 'Ship Android Widget Update',
        dueDate: DateTime(2026, 11, 5, 18, 0),
        priority: TaskPriority.high,
        subtasks: const [
          TaskSubtask(title: '7x6 Calendar Grid', isCompleted: true),
          TaskSubtask(title: 'High-density Day View', isCompleted: false),
          TaskSubtask(title: '7-day Week Agenda', isCompleted: false),
        ],
      );

      await WidgetSyncService.updateAllWidgets(
        tasks: [task],
        anchor: DateTime(2026, 11, 5),
      );

      // Verify payloads were serialized and sent to home_widget
      expect(savedWidgetData.containsKey('waypoint_day_payload'), true);
      expect(savedWidgetData.containsKey('waypoint_month_payload'), true);
      expect(savedWidgetData.containsKey('waypoint_week_payload'), true);

      // Verify Day payload JSON is valid and formatted with title, due time, priority, subtask progress
      final dayJson = savedWidgetData['waypoint_day_payload'] as String;
      final dayData = jsonDecode(dayJson) as Map<String, dynamic>;
      expect(dayData['date'], '2026-11-05');
      expect(dayData['tasks'], isNotEmpty);

      final taskItem = (dayData['tasks'] as List).first as Map<String, dynamic>;
      expect(taskItem['title'], 'Ship Android Widget Update');
      expect(taskItem['priority'], 'high');
      expect(taskItem['due_time'], '18:00');
      expect(taskItem['subtask_progress'], '1/3');
      expect(taskItem['total_subtasks'], 3);
      expect(taskItem['completed_subtasks'], 1);

      // Verify Month payload JSON is valid and readable
      final monthJson = savedWidgetData['waypoint_month_payload'] as String;
      final monthData = jsonDecode(monthJson) as Map<String, dynamic>;
      expect(monthData['month_title'], 'November 2026');
      final monthDays = monthData['days'] as Map<String, dynamic>;
      expect(monthDays.containsKey('2026-11-05'), true);

      // Verify all 3 widget providers were updated
      expect(updatedWidgets.contains('WaypointMonthWidgetProvider'), true);
      expect(updatedWidgets.contains('WaypointWeekWidgetProvider'), true);
      expect(updatedWidgets.contains('WaypointDayWidgetProvider'), true);
    });
  });
}
