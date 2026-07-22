import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

class TaskItemCard extends StatelessWidget {
  final Event event;
  final Function() onTap;
  final Function(DismissDirection) onDismiss;

  const TaskItemCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDone = event.status == Status.done;
    final isOverdue = !isDone && event.dateTime.isBefore(DateTime.now());

    Color cardColor;
    if (event.priority == Priority.high) {
      cardColor = Color.lerp(Theme.of(context).cardColor, Colors.red, 0.1)!;
    } else if (event.priority == Priority.low) {
      cardColor = Color.lerp(Theme.of(context).cardColor, Colors.blueGrey, 0.1)!;
    } else {
      cardColor = Theme.of(context).cardColor;
    }

    return Dismissible(
      key: ValueKey(event.id),
      background: _buildDismissBackground(colorScheme, Icons.check, colorScheme.primary, Alignment.centerLeft),
      secondaryBackground: _buildDismissBackground(colorScheme, Icons.delete_outline, Colors.red.shade400, Alignment.centerRight),
      onDismissed: (direction) {
        HapticFeedback.mediumImpact();
        onDismiss(direction);
      },
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
                _buildStatusIcon(isDone, colorScheme),
                const SizedBox(width: 16),
                _buildTaskContent(context, isDone, colorScheme),
                const SizedBox(width: 16),
                _buildTrailingInfo(isOverdue, colorScheme),
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

  Widget _buildStatusIcon(bool isDone, ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDone ? Colors.green : colorScheme.outline,
          width: 2,
        ),
      ),
      child: isDone ? const Icon(Icons.check, size: 14, color: Colors.green) : null,
    );
  }

  Widget _buildTaskContent(BuildContext context, bool isDone, ColorScheme colorScheme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? colorScheme.onSurface.withOpacity(0.5) : colorScheme.onSurface,
            ),
          ),
          if (event.description.isNotEmpty)
            Text(
              event.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildPillTag(colorScheme, event.priority.name.toUpperCase(), colorScheme.primary),
              ...event.assignees.take(2).map((a) => _buildPillTag(colorScheme, a, colorScheme.tertiary, isAssignee: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingInfo(bool isOverdue, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          DateFormat.yMMMd().format(event.dateTime),
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
        if (isOverdue)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag, color: Colors.red, size: 12),
                const SizedBox(width: 2),
                const Text('Overdue', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
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
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
