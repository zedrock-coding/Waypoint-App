import 'dart:async';
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
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _notificationChannel;

  Future<void> init() async {
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

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification click: Navigate to specific task/community if needed
      },
    );

    // Initial setup for logged in user
    if (_supabase.auth.currentUser != null) {
      listenToSupabaseNotifications();
    }

    // Listen for auth changes
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        listenToSupabaseNotifications();
      } else if (data.event == AuthChangeEvent.signedOut) {
        stopListening();
      }
    });
  }

  void listenToSupabaseNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationChannel?.unsubscribe();
    _notificationChannel = _supabase
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
  }

  Future<bool> requestPermissions() async {
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final bool? androidGranted = await androidPlugin?.requestNotificationsPermission();
    
    final bool? iosGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return (androidGranted ?? false) || (iosGranted ?? false);
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
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
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> scheduleTaskDueDateNotification({
    required String taskId,
    required String title,
    required DateTime dueAt,
  }) async {
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
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    final int baseId = taskId.hashCode;
    await _notificationsPlugin.cancel(baseId);
    await _notificationsPlugin.cancel(baseId + 1);
    await _notificationsPlugin.cancel(baseId + 2);
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
