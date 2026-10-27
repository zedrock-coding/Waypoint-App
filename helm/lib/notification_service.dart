import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:hive/hive.dart';
import 'models/hive_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _notificationChannel;

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
        await _notificationsPlugin.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse details) {
            // Handle notification click: Navigate to specific task/community if needed
          },
        );
      }
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }

    // Initial setup for logged in user
    final client = _supabase;
    if (client != null) {
      if (client.auth.currentUser != null) {
        listenToSupabaseNotifications();
      }

      // Listen for auth changes
      client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          listenToSupabaseNotifications();
        } else if (data.event == AuthChangeEvent.signedOut) {
          stopListening();
        }
      });
    }
  }

  void listenToSupabaseNotifications() {
    final client = _supabase;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    _notificationChannel?.unsubscribe();
    _notificationChannel = client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleNewNotification(payload.newRecord);
          },
        )
        .subscribe();
  }

  void stopListening() {
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
  }

  void _handleNewNotification(Map<String, dynamic> data) {
    final type = data['type'] as String;
    final title = data['title'] as String;
    final body = data['body'] as String;

    // Check user preferences from Hive
    final settings = Hive.box<Settings>('settings').get('app_settings');
    if (settings != null) {
      bool isEnabled = true;
      switch (type) {
        case 'task_assignment':
          isEnabled = settings.taskAssignmentsEnabled ?? true;
          break;
        case 'due_reminder':
        case 'task_overdue':
          isEnabled = settings.dueDateRemindersEnabled ?? true;
          break;
        case 'community_mention':
          isEnabled = settings.communityMentionsEnabled ?? true;
          break;
      }
      
      if (!isEnabled) {
        debugPrint('Notification suppressed by user settings: $type');
        return;
      }
    }

    _showLocalNotification(
      id: data['id'].hashCode,
      title: title,
      body: body,
      payload: data['related_id']?.toString(),
    );
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    try {
      const androidDetails = AndroidNotificationDetails(
        'helm_notifications',
        'Helm Notifications',
        channelDescription: 'Real-time task and community updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );

      await _notificationsPlugin.show(id, title, body, notificationDetails, payload: payload);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return true;
    }
    try {
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? androidGranted = await androidPlugin?.requestNotificationsPermission();
      
      final bool? iosGranted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      return (androidGranted ?? false) || (iosGranted ?? false);
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
      return true;
    }
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders',
            'Daily Reminders',
            channelDescription: 'Daily task reminder notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Failed to schedule daily notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }

  Future<void> scheduleTaskDueDateNotification({
    required String taskId,
    required String title,
    required DateTime dueAt,
  }) async {
    // Check user preference
    final settings = Hive.isBoxOpen('settings') ? Hive.box<Settings>('settings').get('app_settings') : null;
    final isEnabled = settings?.dueDateRemindersEnabled ?? true;
    if (!isEnabled) {
      debugPrint('Task due date notification suppressed: setting disabled');
      return;
    }

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }

    final int baseId = taskId.hashCode;
    final now = DateTime.now();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Notifications for due tasks',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      try {
        tz.initializeTimeZones();
      } catch (_) {}

      // 1. Exact due time
      if (dueAt.isAfter(now)) {
        final tzDueAt = tz.TZDateTime.from(dueAt, tz.local);
        await _notificationsPlugin.zonedSchedule(
          baseId,
          'Task Due Now!',
          'Task "$title" is due right now.',
          tzDueAt,
          details,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      // 2. 1 Hour Before
      final oneHourBefore = dueAt.subtract(const Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        final tzOneHour = tz.TZDateTime.from(oneHourBefore, tz.local);
        await _notificationsPlugin.zonedSchedule(
          baseId + 1,
          'Task Due Soon (1 Hour)',
          'Task "$title" is due in 1 hour.',
          tzOneHour,
          details,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      // 3. 24 Hours Before
      final dayBefore = dueAt.subtract(const Duration(hours: 24));
      if (dayBefore.isAfter(now)) {
        final tzDayBefore = tz.TZDateTime.from(dayBefore, tz.local);
        await _notificationsPlugin.zonedSchedule(
          baseId + 2,
          'Task Due Tomorrow',
          'Task "$title" is due in 24 hours.',
          tzDayBefore,
          details,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Failed to schedule task due date notification: $e');
    }
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    try {
      final int baseId = taskId.hashCode;
      await _notificationsPlugin.cancel(baseId);
      await _notificationsPlugin.cancel(baseId + 1);
      await _notificationsPlugin.cancel(baseId + 2);
    } catch (e) {
      debugPrint('Failed to cancel task notification: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
