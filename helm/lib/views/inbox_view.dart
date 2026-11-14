import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unified_task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/task_item_card.dart';

class InboxView extends StatelessWidget {
  final Function(UnifiedTask) onTaskTap;

  const InboxView({super.key, required this.onTaskTap});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final inboxTasks = taskProvider.tasksAssignedByOthers;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 896),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'INBOX & ASSIGNMENTS',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mint,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•', style: TextStyle(color: AppTheme.surfaceVariant)),
                      ),
                      Text(
                        'Shared Workspaces',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Assigned by Others',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${inboxTasks.length} tasks delegated across your communities',
                    style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.surfaceVariant, height: 1),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (inboxTasks.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 40, color: AppTheme.mint),
                      const SizedBox(height: 12),
                      const Text(
                        'Inbox is clear',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No tasks assigned by others in your active communities.',
                        style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...inboxTasks.asMap().entries.map((entry) {
                final task = entry.value;
                final index = entry.key;
                return TaskItemCard(
                  key: ValueKey('inbox_${task.id}'),
                  task: task,
                  index: index,
                  onTap: () => onTaskTap(task),
                  onToggle: () => taskProvider.toggleTask(task),
                  onDismiss: (_) => taskProvider.deleteTask(task.id, taskBackup: task),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
