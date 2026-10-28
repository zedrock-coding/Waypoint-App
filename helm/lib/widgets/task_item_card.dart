import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'user_avatar.dart';
import '../models/unified_task.dart';
import '../models/hive_models.dart' as hive_model;
import '../services/supabase_service.dart';

class TaskItemCard extends StatelessWidget {
  final UnifiedTask task;
  final int index;
  final Function() onTap;
  final Function() onToggle;
  final Function(DismissDirection) onDismiss;

  const TaskItemCard({
    super.key,
    required this.task,
    required this.index,
    required this.onTap,
    required this.onToggle,
    required this.onDismiss,
  });

  Color _getPriorityColor(Priority p) {
    switch (p) {
      case Priority.high: return Colors.redAccent;
      case Priority.medium: return Colors.amber;
      case Priority.low: return Colors.blueGrey;
    }
  }

  IconData _getPriorityIcon(Priority p) {
    switch (p) {
      case Priority.high: return Icons.keyboard_double_arrow_up_rounded;
      case Priority.medium: return Icons.remove_rounded;
      case Priority.low: return Icons.keyboard_arrow_down_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = task.status == Status.done;
    final isOverdue = !isDone && task.dateTime.isBefore(DateTime.now());
    final priorityColor = _getPriorityColor(task.priority);

    return Dismissible(
      key: ValueKey('dismiss_${task.isLocal ? 'l' : 'r'}_${task.id}'),
      background: _buildDismissBackground(
        colorScheme, 
        isDone ? Icons.undo : Icons.check, 
        isDone ? Colors.orange : colorScheme.primary, 
        Alignment.centerLeft
      ),
      secondaryBackground: _buildDismissBackground(
        colorScheme, 
        Icons.delete_outline, 
        Colors.red.shade400, 
        Alignment.centerRight
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.mediumImpact();
          onToggle();
          return false; 
        }
        return true; 
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          HapticFeedback.mediumImpact();
          onDismiss(direction);
        }
      },
      child: Hero(
        tag: 'task_card_${task.id}',
        child: Card(
          elevation: 0,
          color: Theme.of(context).cardColor,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias, // Important for the left border line
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Row(
              children: [
                // 1. Priority Left Accent Line
                Container(
                  width: 4,
                  height: 70, // Matches approximate tile height
                  color: priorityColor,
                ),
                const SizedBox(width: 12),
                
                // 2. Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: onToggle,
                          child: _buildStatusIcon(task.status, colorScheme),
                        ),
                        const SizedBox(width: 12),
                        _buildAssigneeAvatar(colorScheme),
                        const SizedBox(width: 12),
                        _buildTaskContent(context, isDone, colorScheme, priorityColor),
                        const SizedBox(width: 16),
                        _buildTrailingInfo(isOverdue, colorScheme),
                        const SizedBox(width: 8),
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: colorScheme.onSurface.withValues(alpha: 0.2),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(ColorScheme colorScheme, IconData icon, Color color, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildStatusIcon(Status status, ColorScheme colorScheme) {
    switch (status) {
      case Status.done:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        );
      case Status.inProgress:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.primary, width: 2),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary),
            ),
          ),
        );
      default:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outline, width: 2),
          ),
        );
    }
  }

  Widget _buildAssigneeAvatar(ColorScheme colorScheme) {
    if (task.assignees.isEmpty) return const SizedBox.shrink();

    // Show the real assignee. The card only has ids, so resolve the name from
    // the (cached) community roster; fall back to the id prefix while loading.
    final String assigneeId = task.assignees.first;
    final communityId = task.communityId;

    if (communityId == null) {
      return UserAvatar(fullName: _shortId(assigneeId), radius: 12);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService().getCommunityMembers(communityId),
      builder: (context, snapshot) {
        String? name;
        for (final member in snapshot.data ?? const <Map<String, dynamic>>[]) {
          if (member['user_id']?.toString() == assigneeId) {
            name = member['full_name']?.toString();
            break;
          }
        }
        return UserAvatar(fullName: name ?? _shortId(assigneeId), radius: 12);
      },
    );
  }

  String _shortId(String id) => id.length > 4 ? id.substring(0, 4) : id;

  Widget _buildTaskContent(BuildContext context, bool isDone, ColorScheme colorScheme, Color priorityColor) {
    final categoryBox = Hive.box<hive_model.Category>('categories');
    final names = task.categoryIds
        .map((id) => categoryBox.get(id)?.name)
        .whereType<String>()
        .toList();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(
            task.title,
            maxLines: 1, 
            overflow: TextOverflow.ellipsis, 
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? colorScheme.onSurface.withValues(alpha: 0.5) : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView( 
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPillTag(colorScheme, task.status.name.toUpperCase(), _getStatusColor(task.status)),
                const SizedBox(width: 4),
                _buildPillTag(
                  colorScheme, 
                  task.priority.name.toUpperCase(), 
                  priorityColor, 
                  icon: _getPriorityIcon(task.priority)
                ),
                for (var name in names) ...[
                   const SizedBox(width: 4),
                   _buildPillTag(colorScheme, name.toUpperCase(), colorScheme.secondary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(Status s) {
    switch (s) {
      case Status.done: return Colors.green;
      case Status.inProgress: return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildTrailingInfo(bool isOverdue, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          DateFormat.yMMMd().format(task.dateTime),
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
        if (isOverdue)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.error_outline, color: Colors.red, size: 14),
          ),
      ],
    );
  }

  Widget _buildPillTag(ColorScheme colorScheme, String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
