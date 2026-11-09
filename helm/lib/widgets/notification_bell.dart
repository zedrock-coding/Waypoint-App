import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waypoint/features/dispatch/domain/services/needle_morning_dispatch_service.dart';
import 'notification_feed.dart';

class NotificationBellWidget extends StatefulWidget {
  final bool isDesktop;
  final LayerLink layerLink;
  final VoidCallback onToggle;

  const NotificationBellWidget({
    super.key,
    required this.isDesktop,
    required this.layerLink,
    required this.onToggle,
  });

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget> {
  /// Created once. Building the stream inside `build` re-subscribed on every
  /// rebuild of the shell, which is both wasteful and a source of duplicate
  /// realtime events.
  late final Stream<List<Map<String, dynamic>>> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('is_read', false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final remoteCount = snapshot.data?.length ?? 0;
        final localCount = NeedleMorningDispatchService.getLocalNotifications()
            .where((n) => n['is_read'] != true)
            .length;
        final unreadCount = remoteCount + localCount;

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface.withValues(alpha: 0.7)),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            if (widget.isDesktop) {
              widget.onToggle();
            } else {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => const NotificationFeedUI(),
              );
            }
          },
        );
      },
    );
  }
}
