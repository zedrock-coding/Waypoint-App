// lib/core/services/app_initialization_service.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppInitializationService {
  static const String dispatchChannelId = 'waypoint_dispatch_channel';
  static const String dispatchChannelName = 'Waypoint Daily Briefings';
  static const String dispatchChannelDescription =
      'Audio and briefing alerts for daily task dispatches';

  static Future<void> ensureSystemPermissions() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      final androidPlugin = plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Request notification permissions
      await androidPlugin?.requestNotificationsPermission();

      // Configure notification channel
      const androidChannel = AndroidNotificationChannel(
        dispatchChannelId,
        dispatchChannelName,
        description: dispatchChannelDescription,
        importance: Importance.max,
        playSound: true,
      );

      await androidPlugin?.createNotificationChannel(androidChannel);
    }
  }
}
