import 'package:flutter/material.dart';

class NotificationFeedUI extends StatelessWidget {
  const NotificationFeedUI({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final List<Map<String, dynamic>> mockNotifications = [
      {
        'type': 'overdue',
        'title': 'Task Overdue',
        'subtitle': 'Your task "Random things" was due yesterday.',
        'isUnread': true,
      },
      {
        'type': 'assignment',
        'title': 'New Assignment',
        'subtitle': 'Lakshya assigned you a task in E-Cell SMM Event.',
        'isUnread': true,
      },
      {
        'type': 'invite',
        'title': 'Community Invite',
        'subtitle': 'You have been invited to join "App Development".',
        'isUnread': false,
      },
    ];

    return RepaintBoundary(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 450, maxWidth: 350),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Mark all as read',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true, // Safe here because parent Container has constraints
                itemCount: mockNotifications.length,
                itemBuilder: (context, index) {
                  final notification = mockNotifications[index];
                  final isUnread = notification['isUnread'] as bool;

                  return Container(
                    color: isUnread ? colorScheme.primary.withOpacity(0.05) : null,
                    child: ListTile(
                      dense: true,
                      leading: _buildLeadingIcon(context, notification['type']),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        notification['subtitle'],
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      trailing: isUnread
                          ? Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, String type) {
    switch (type) {
      case 'overdue':
        return const Icon(Icons.flag, color: Colors.redAccent, size: 20);
      case 'assignment':
        return Icon(Icons.assignment_ind, color: Theme.of(context).colorScheme.primary, size: 20);
      case 'invite':
        return const Icon(Icons.group_add, color: Colors.blueAccent, size: 20);
      default:
        return const Icon(Icons.notifications, size: 20);
    }
  }
}
