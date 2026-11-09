import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_morning_dispatch_service.dart';

class NotificationFeedUI extends StatefulWidget {
  const NotificationFeedUI({super.key});

  @override
  State<NotificationFeedUI> createState() => _NotificationFeedUIState();
}

class _NotificationFeedUIState extends State<NotificationFeedUI> {
  final _supabase = Supabase.instance.client;

  /// Created once per screen open; building it in `build` re-subscribed on
  /// every rebuild.
  late final Stream<List<Map<String, dynamic>>> _feedStream;

  @override
  void initState() {
    super.initState();
    _feedStream = _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(20);
  }

  Future<void> _markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
      } catch (e) {
        debugPrint('Error marking remote notifications as read: $e');
      }
    }

    await NeedleMorningDispatchService.markAllLocalNotificationsRead();
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> _getCombinedNotifications(
      List<Map<String, dynamic>> remote) {
    final local = NeedleMorningDispatchService.getLocalNotifications();
    final seenIds = <String>{};
    final combined = <Map<String, dynamic>>[];

    for (final item in remote) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) seenIds.add(id);
      combined.add(item);
    }

    for (final item in local) {
      final id = item['id']?.toString() ?? '';
      if (!seenIds.contains(id)) {
        seenIds.add(id);
        combined.add(item);
      }
    }

    combined.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 500, maxWidth: 380),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle for mobile
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text('Mark all as read'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _feedStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  final localFallback = NeedleMorningDispatchService.getLocalNotifications();
                  if (localFallback.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                }

                final rawRemote = snapshot.data ?? [];
                final notifications = _getCombinedNotifications(rawRemote);

                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: colorScheme.onSurface.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'All caught up!',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final isRead = item['is_read'] == true;
                    final date = DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now();
                    final title = item['title']?.toString() ?? 'Notification';
                    final body = item['body']?.toString() ?? '';
                    final type = item['type']?.toString() ?? '';
                    final id = item['id']?.toString() ?? '';

                    return Material(
                      color: isRead
                          ? Colors.transparent
                          : colorScheme.primary.withValues(alpha: 0.03),
                      child: InkWell(
                        onTap: () async {
                          if (!isRead) {
                            if (id.startsWith('local_')) {
                              await NeedleMorningDispatchService.markLocalNotificationRead(id);
                            } else {
                              try {
                                await _supabase
                                    .from('notifications')
                                    .update({'is_read': true})
                                    .eq('id', id);
                              } catch (_) {}
                            }
                            if (mounted) setState(() {});
                          }
                          if (type == 'daily_briefing' && body.isNotEmpty) {
                            NeedleMorningDispatchService.playBriefing(script: body);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildIcon(context, type),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isRead
                                                  ? FontWeight.normal
                                                  : FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          DateFormat.jm().format(date),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      body,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    if (type == 'daily_briefing') ...[
                                      const SizedBox(height: 8),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: NeedleMorningDispatchService.isPlayingNotifier,
                                        builder: (context, isPlaying, _) {
                                          final isCurrentPlaying = isPlaying &&
                                              NeedleMorningDispatchService.currentlyPlayingText == body;
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () {
                                                if (isCurrentPlaying) {
                                                  NeedleMorningDispatchService.stopBriefing();
                                                } else {
                                                  NeedleMorningDispatchService.playBriefing(script: body);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF88C0A4).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(0xFF88C0A4).withValues(alpha: 0.35),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isCurrentPlaying
                                                          ? Icons.stop_circle_rounded
                                                          : Icons.play_circle_fill_rounded,
                                                      size: 16,
                                                      color: const Color(0xFF88C0A4),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isCurrentPlaying
                                                          ? 'Stop Briefing'
                                                          : 'Play Briefing',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF88C0A4),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 4),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context, String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'daily_briefing':
        iconData = Icons.record_voice_over_rounded;
        iconColor = const Color(0xFF88C0A4);
        break;
      case 'task_assignment':
        iconData = Icons.assignment_ind_rounded;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      case 'due_reminder':
        iconData = Icons.alarm_rounded;
        iconColor = Colors.orange;
        break;
      case 'task_overdue':
        iconData = Icons.error_outline_rounded;
        iconColor = Colors.redAccent;
        break;
      case 'community_mention':
        iconData = Icons.alternate_email_rounded;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.notifications_rounded;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 18, color: iconColor),
    );
  }
}
