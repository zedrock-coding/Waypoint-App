import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/unified_task.dart';
import '../models/hive_models.dart' as hive_model;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = task.status == Status.done;
    final isOverdue = !isDone && task.dateTime.isBefore(DateTime.now());

    Color cardColor;
    if (task.priority == Priority.high) {
      cardColor = Color.lerp(Theme.of(context).cardColor, Colors.red, 0.05)!;
    } else if (task.priority == Priority.low) {
      cardColor = Color.lerp(Theme.of(context).cardColor, Colors.blueGrey, 0.05)!;
    } else {
      cardColor = Theme.of(context).cardColor;
    }

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
          color: cardColor,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: _buildStatusIcon(task.status, colorScheme),
                  ),
                  const SizedBox(width: 16),
                  _buildTaskContent(context, isDone, colorScheme),
                  const SizedBox(width: 16),
                  _buildTrailingInfo(isOverdue, colorScheme),
                  const SizedBox(width: 8),
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: colorScheme.onSurface.withOpacity(0.2),
                      size: 20,
                    ),
                  ),
                ],
              ),
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

  Widget _buildTaskContent(BuildContext context, bool isDone, ColorScheme colorScheme) {
    // Fetch category names from IDs
    final categoryBox = Hive.box<hive_model.Category>('categories');
    final names = task.categoryIds
        .map((id) => categoryBox.get(id)?.name)
        .whereType<String>()
        .toList();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(
            task.title,
            maxLines: 2, 
            overflow: TextOverflow.ellipsis, 
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? colorScheme.onSurface.withOpacity(0.5) : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView( 
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPillTag(colorScheme, task.status.name.toUpperCase(), _getStatusColor(task.status)),
                const SizedBox(width: 4),
                _buildPillTag(colorScheme, task.priority.name.toUpperCase(), colorScheme.primary),
                for (var name in names) ...[
                   const SizedBox(width: 4),
                   _buildPillTag(colorScheme, name.toUpperCase(), colorScheme.secondary),
                ],
                if (!task.isLocal) ...[
                  const SizedBox(width: 4),
                  _buildPillTag(colorScheme, 'CLOUD', Colors.blue, isAssignee: false),
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

  Widget _buildPillTag(ColorScheme colorScheme, String label, Color color, {bool isAssignee = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
