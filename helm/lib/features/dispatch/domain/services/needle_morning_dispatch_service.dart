// lib/features/dispatch/domain/services/needle_morning_dispatch_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:workmanager/workmanager.dart';

import 'package:waypoint/features/task/domain/models/task.dart';
import 'package:waypoint/features/voice/data/sherpa_tts_service.dart';
import 'package:waypoint/features/voice/domain/services/tts_service.dart';
import 'package:waypoint/models/hive_models.dart' as hive_m;
import 'needle_dispatch_engine.dart';

@pragma('vm:entry-point')
void dispatchCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == NeedleMorningDispatchService.taskName ||
        taskName == Workmanager.iOSBackgroundTask) {
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

  static String? lastGeneratedScript;
  static ITextToSpeechService? defaultTtsService;

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
          payload: playBriefingActionId,
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
    final textToSpeak = script ?? lastGeneratedScript;
    if (textToSpeak == null || textToSpeak.isEmpty) {
      debugPrint('NeedleMorningDispatchService: No script available to play');
      return;
    }

    final tts = ttsService ?? defaultTtsService ?? SherpaTtsService();
    try {
      await tts.initialize();
      await tts.speak(textToSpeak);
    } catch (e) {
      debugPrint('NeedleMorningDispatchService: Error playing briefing: $e');
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
