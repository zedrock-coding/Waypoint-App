import 'package:flutter_test/flutter_test.dart';
import 'package:helm/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Resilience and Settings Tests', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    test('NotificationService is singleton instance', () {
      final instance1 = NotificationService();
      final instance2 = NotificationService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('requestPermissions returns safely across environments', () async {
      final result = await service.requestPermissions();
      expect(result, isA<bool>());
    });

    test('scheduleTaskDueDateNotification executes safely without crashing', () async {
      await expectLater(
        service.scheduleTaskDueDateNotification(
          taskId: 'task-test-101',
          title: 'Unit Test Task',
          dueAt: DateTime.now().add(const Duration(hours: 2)),
        ),
        completes,
      );
    });

    test('cancelTaskNotifications executes safely without crashing', () async {
      await expectLater(
        service.cancelTaskNotifications('task-test-101'),
        completes,
      );
    });

    test('cancelAllNotifications executes safely without crashing', () async {
      await expectLater(
        service.cancelAllNotifications(),
        completes,
      );
    });
  });
}
