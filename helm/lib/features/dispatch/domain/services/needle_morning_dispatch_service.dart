// lib/features/dispatch/domain/services/needle_morning_dispatch_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'package:waypoint/features/task/domain/models/task.dart';
import 'package:waypoint/features/voice/data/sherpa_tts_service.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';
import 'package:waypoint/models/hive_models.dart' as hive_m;
import 'package:waypoint/services/hive_database.dart';
import 'needle_dispatch_engine.dart';

@pragma('vm:entry-point')
void dispatchCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == NeedleMorningDispatchService.taskName ||
        taskName == Workmanager.iOSBackgroundTask) {
      if (!Hive.isBoxOpen('tasks')) {
        try {
          await HiveDatabase.init();
        } catch (e) {
          debugPrint('dispatchCallbackDispatcher Hive init error: $e');
        }
      }
      await NeedleMorningDispatchService.executeDailyDispatch();
    }
    return Future.value(true);
  });
}

class NeedleMorningDispatchService {
  static const String taskName = 'waypoint_dispatch_morning';
  static const String taskTag = 'waypoint_dispatch_tag';
  static const String channelId = 'waypoint_dispatch';
  static const String channelName = 'Waypoint Daily Dispatch';
  static const String playBriefingActionId = 'play_briefing';
  static const String localNotificationsKey = 'local_notifications_list';
  static const String briefingScriptKey = 'latest_daily_briefing_script';
  static const String briefingTimeKey = 'latest_daily_briefing_time';

  static String? lastGeneratedScript;
  static ITextToSpeechService? defaultTtsService;
  static final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  static String? currentlyPlayingText;

  static final List<Map<String, dynamic>> _inMemoryLocalNotifications = [];

  static Duration calculateInitialDelay([DateTime? now]) {
    final current = now ?? DateTime.now();
    var target = DateTime(current.year, current.month, current.day, 8, 0, 0);
    if (current.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(current);
  }

  static Future<void> scheduleDailyDispatch({
    Workmanager? workmanager,
    DateTime? now,
  }) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    final wm = workmanager ?? Workmanager();
    try {
      await wm.initialize(
        dispatchCallbackDispatcher,
      );

      final initialDelay = calculateInitialDelay(now);
      await wm.registerPeriodicTask(
        taskName,
        taskName,
        tag: taskTag,
        frequency: const Duration(hours: 24),
        initialDelay: initialDelay,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error scheduling task: $e');
    }
  }

  static Future<void> executeDailyDispatch({
    List<Task>? tasks,
    DateTime? now,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    ITextToSpeechService? ttsService,
    SupabaseClient? supabaseClient,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    List<Task> pendingTasks = tasks ?? [];

    if (tasks == null) {
      try {
        if (Hive.isBoxOpen('tasks')) {
          final box = Hive.box<hive_m.Task>('tasks');
          pendingTasks = box.values
              .where((t) => t.isCompleted != true)
              .map((t) => Task(
                    id: t.id ?? '',
                    title: t.title ?? 'Untitled',
                    description: t.description,
                    dueDate: t.dueAt,
                    priority: _parsePriority(t.priority),
                  ))
              .toList();
        }
      } catch (e) {
        debugPrint('NeedleMorningDispatchService: Error reading tasks: $e');
      }
    }

    final summary = NeedleDispatchEngine.filter(pendingTasks, effectiveNow);
    final script = NeedleDispatchEngine.compileBriefingScript(summary);
    lastGeneratedScript = script;

    // 1. Persist script to local user_stats Hive box if open
    try {
      if (Hive.isBoxOpen('user_stats')) {
        final statsBox = Hive.box('user_stats');
        await statsBox.put(briefingScriptKey, script);
        await statsBox.put(briefingTimeKey, effectiveNow.toIso8601String());
      }
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error persisting script to Hive: $e');
    }

    // 2. Persist local in-app notification for offline / immediate availability
    final localNotification = <String, dynamic>{
      'id': 'local_briefing_${effectiveNow.millisecondsSinceEpoch}',
      'type': 'daily_briefing',
      'title': 'Daily Briefing',
      'body': script,
      'is_read': false,
      'created_at': effectiveNow.toIso8601String(),
    };
    await saveLocalNotification(localNotification);

    // 3. Persist remote in-app notification in Supabase if logged in
    try {
      final client = supabaseClient ?? _resolveSupabaseClient();
      final userId = client?.auth.currentUser?.id;
      if (client != null && userId != null) {
        await client.from('notifications').insert({
          'user_id': userId,
          'type': 'daily_briefing',
          'title': 'Daily Briefing',
          'body': script,
          'is_read': false,
          'created_at': effectiveNow.toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error inserting remote notification: $e');
    }

    // 4. Fire system notification with script in payload
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
      try {
        final plugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();

        const androidDetails = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Daily morning briefing and task alerts',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              playBriefingActionId,
              'Play Briefing',
              showsUserInterface: true,
            ),
          ],
        );

        const notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        await plugin.show(
          8000,
          'Waypoint Daily Dispatch',
          script,
          notificationDetails,
          payload: '$playBriefingActionId::$script',
        );
      } catch (e) {
        debugPrint('NeedleMorningDispatchService: Error showing notification: $e');
      }
    }
  }

  static Future<void> playBriefing({
    String? script,
    ITextToSpeechService? ttsService,
  }) async {
    String? textToSpeak = script ?? lastGeneratedScript;

    // Fallback 1: read persisted script from Hive if open
    if (textToSpeak == null || textToSpeak.isEmpty) {
      try {
        if (Hive.isBoxOpen('user_stats')) {
          textToSpeak = Hive.box('user_stats').get(briefingScriptKey) as String?;
        }
      } catch (e) {
        debugPrint('NeedleMorningDispatchService: Error reading script from Hive: $e');
      }
    }

    // Fallback 2: dynamically generate current script on demand
    if (textToSpeak == null || textToSpeak.isEmpty) {
      textToSpeak = await generateCurrentBriefingScript();
    }

    // Fallback 3: safe polite default
    if (textToSpeak.isEmpty) {
      textToSpeak = 'Good morning. You are all caught up with no pending tasks today.';
    }

    lastGeneratedScript = textToSpeak;
    currentlyPlayingText = textToSpeak;
    isPlayingNotifier.value = true;

    final tts = ttsService ?? defaultTtsService ?? SherpaTtsService();
    try {
      await tts.initialize();
      await tts.speak(textToSpeak);
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error playing briefing: $e');
    } finally {
      isPlayingNotifier.value = false;
      currentlyPlayingText = null;
    }
  }

  static Future<void> stopBriefing({ITextToSpeechService? ttsService}) async {
    final tts = ttsService ?? defaultTtsService ?? SherpaTtsService();
    try {
      await tts.stop();
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error stopping briefing: $e');
    } finally {
      isPlayingNotifier.value = false;
      currentlyPlayingText = null;
    }
  }

  static Future<String> generateCurrentBriefingScript([DateTime? now]) async {
    final effectiveNow = now ?? DateTime.now();
    List<Task> pendingTasks = [];

    try {
      if (Hive.isBoxOpen('tasks')) {
        final box = Hive.box<hive_m.Task>('tasks');
        pendingTasks = box.values
            .where((t) => t.isCompleted != true)
            .map((t) => Task(
                  id: t.id ?? '',
                  title: t.title ?? 'Untitled',
                  description: t.description,
                  dueDate: t.dueAt,
                  priority: _parsePriority(t.priority),
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error reading tasks for dynamic script: $e');
    }

    final summary = NeedleDispatchEngine.filter(pendingTasks, effectiveNow);
    return NeedleDispatchEngine.compileBriefingScript(summary);
  }

  static Future<void> saveLocalNotification(Map<String, dynamic> notification) async {
    _inMemoryLocalNotifications.removeWhere((item) => item['id'] == notification['id']);
    _inMemoryLocalNotifications.insert(0, notification);
    if (_inMemoryLocalNotifications.length > 30) {
      _inMemoryLocalNotifications.removeRange(30, _inMemoryLocalNotifications.length);
    }

    try {
      if (Hive.isBoxOpen('user_stats')) {
        final box = Hive.box('user_stats');
        final list = List<Map<dynamic, dynamic>>.from(
          box.get(localNotificationsKey, defaultValue: <dynamic>[]) as List,
        );
        list.removeWhere((item) => item['id'] == notification['id']);
        list.insert(0, notification);
        if (list.length > 30) {
          list.removeRange(30, list.length);
        }
        await box.put(localNotificationsKey, list);
      }
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error saving local notification to Hive: $e');
    }
  }

  static List<Map<String, dynamic>> getLocalNotifications() {
    try {
      if (Hive.isBoxOpen('user_stats')) {
        final box = Hive.box('user_stats');
        final rawList = box.get(localNotificationsKey, defaultValue: <dynamic>[]) as List;
        final fromHive = rawList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        final seen = <String>{};
        final combined = <Map<String, dynamic>>[];
        for (final item in [..._inMemoryLocalNotifications, ...fromHive]) {
          final id = item['id']?.toString() ?? '';
          if (id.isNotEmpty && !seen.contains(id)) {
            seen.add(id);
            combined.add(item);
          }
        }
        return combined;
      }
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error reading local notifications: $e');
    }
    return List<Map<String, dynamic>>.from(_inMemoryLocalNotifications);
  }

  static Future<void> markLocalNotificationRead(String id) async {
    for (var item in _inMemoryLocalNotifications) {
      if (item['id'] == id) {
        item['is_read'] = true;
      }
    }
    try {
      if (Hive.isBoxOpen('user_stats')) {
        final box = Hive.box('user_stats');
        final list = List<Map<dynamic, dynamic>>.from(
          box.get(localNotificationsKey, defaultValue: <dynamic>[]) as List,
        );
        for (var item in list) {
          if (item['id'] == id) {
            item['is_read'] = true;
          }
        }
        await box.put(localNotificationsKey, list);
      }
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error updating local notification: $e');
    }
  }

  static Future<void> markAllLocalNotificationsRead() async {
    for (var item in _inMemoryLocalNotifications) {
      item['is_read'] = true;
    }
    try {
      if (Hive.isBoxOpen('user_stats')) {
        final box = Hive.box('user_stats');
        final list = List<Map<dynamic, dynamic>>.from(
          box.get(localNotificationsKey, defaultValue: <dynamic>[]) as List,
        );
        for (var item in list) {
          item['is_read'] = true;
        }
        await box.put(localNotificationsKey, list);
      }
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error marking all read: $e');
    }
  }

  static SupabaseClient? _resolveSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static TaskPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'urgent':
        return TaskPriority.urgent;
      case 'high':
        return TaskPriority.high;
      case 'medium':
        return TaskPriority.medium;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }
}
