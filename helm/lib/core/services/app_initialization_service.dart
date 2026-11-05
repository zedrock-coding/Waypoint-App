// lib/core/services/app_initialization_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_morning_dispatch_service.dart';

abstract class NotificationPermissionHandler {
  Future<PermissionStatus> checkStatus();
  Future<PermissionStatus> requestPermission();
}

class RealNotificationPermissionHandler implements NotificationPermissionHandler {
  const RealNotificationPermissionHandler();

  @override
  Future<PermissionStatus> checkStatus() async {
    return await Permission.notification.status;
  }

  @override
  Future<PermissionStatus> requestPermission() async {
    return await Permission.notification.request();
  }
}

class AppInitializationService {
  static const String dispatchChannelId = 'waypoint_dispatch';
  static const String dispatchChannelName = 'Waypoint Daily Dispatch';
  static const String dispatchChannelDescription =
      'Audio and briefing alerts for daily task dispatches';

  static NotificationPermissionHandler permissionHandler =
      const RealNotificationPermissionHandler();

  static Future<void> init({
    NotificationPermissionHandler? customPermissionHandler,
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    bool registerChannel = true,
    bool scheduleDispatch = true,
  }) async {
    final handler = customPermissionHandler ?? permissionHandler;

    // First-Launch Permission Request
    try {
      final status = await handler.checkStatus();
      if (status.isDenied || !status.isGranted) {
        await handler.requestPermission();
      }
    } catch (e) {
      debugPrint('AppInitializationService: Permission request error: $e');
    }

    // Register notification channel
    if (registerChannel && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final plugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin();
        final androidPlugin = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        const androidChannel = AndroidNotificationChannel(
          dispatchChannelId,
          dispatchChannelName,
          description: dispatchChannelDescription,
          importance: Importance.max,
          playSound: true,
        );

        await androidPlugin?.createNotificationChannel(androidChannel);
      } catch (e) {
        debugPrint('AppInitializationService: Channel registration error: $e');
      }
    }

    // Schedule 08:00 AM Needle Morning Dispatch
    if (scheduleDispatch &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await NeedleMorningDispatchService.scheduleDailyDispatch();
      } catch (e) {
        debugPrint('AppInitializationService: Schedule dispatch error: $e');
      }
    }
  }

  static Future<void> ensureSystemPermissions() => init();
}
