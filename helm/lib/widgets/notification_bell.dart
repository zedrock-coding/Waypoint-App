import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_feed.dart';

class NotificationBellWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('is_read', false),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.length ?? 0;

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none_rounded, color: colorScheme.onSurface.withOpacity(0.7)),
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
            if (isDesktop) {
              onToggle();
            } else {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => NotificationFeedUI(),
              );
            }
          },
        );
      },
    );
  }
}
