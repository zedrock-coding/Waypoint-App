import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'models/event.dart';
import 'widgets/task_form_utils.dart';

class TaskDetailScreen extends StatelessWidget {
  final Event event;
  final Isar isar;

  const TaskDetailScreen({super.key, required this.event, required this.isar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: TaskDetailContent(event: event, isar: isar),
    );
  }
}

class TaskDetailContent extends StatelessWidget {
  final Event event;
  final Isar isar;
  final VoidCallback? onClose;
  final bool useHero;

  const TaskDetailContent({
    super.key, 
    required this.event, 
    required this.isar,
    this.onClose,
    this.useHero = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget content = Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onClose != null) const SizedBox(height: 32), // Padding for close button
                    Text(
                      event.title,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTags(context),
                  ],
                ),
              ),
              
              // Body Section
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      _buildSectionTitle(context, 'Description'),
                      const SizedBox(height: 8),
                      Text(
                        event.description.isNotEmpty ? event.description : 'No description provided.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildInfoRow(
                        context, 
                        icon: Icons.calendar_today, 
                        label: 'Created On', 
                        value: DateFormat.yMMMMd().format(event.dateTime),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context, 
                        icon: Icons.access_time, 
                        label: 'Due Date', 
                        value: DateFormat.yMMMMd().add_jm().format(event.dateTime),
                      ),
                      
                      const SizedBox(height: 40),
                      _buildSectionTitle(context, 'Sub-tasks'),
                      const SizedBox(height: 16),
                      _buildSubtasksMockup(context),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Header Buttons (Edit and Close)
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: colorScheme.primary),
                  onPressed: () => showAddTaskForm(context, isar: isar, eventToEdit: event),
                  tooltip: 'Edit Task',
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    tooltip: 'Close Panel',
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (useHero) {
      return Hero(
        tag: 'task_card_${event.id}',
        child: content,
      );
    }
    return content;
  }

  Widget _buildTags(BuildContext context) {
    return FutureBuilder(
      future: event.categories.load(),
      builder: (context, snapshot) {
        final categories = event.categories.toList();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPill(context, event.priority.name.toUpperCase(), isPriority: true),
            ...categories.map((c) => _buildPill(context, c.name)),
          ],
        );
      },
    );
  }

  Widget _buildPill(BuildContext context, String label, {bool isPriority = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isPriority ? colorScheme.primary.withOpacity(0.1) : colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPriority ? colorScheme.primary.withOpacity(0.2) : colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isPriority ? colorScheme.primary : colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withOpacity(0.6))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildSubtasksMockup(BuildContext context) {
    return Column(
      children: [
        _buildMockTask(context, 'Finalize project scope', true),
        _buildMockTask(context, 'Review design assets', false),
        _buildMockTask(context, 'Schedule team sync', false),
      ],
    );
  }

  Widget _buildMockTask(BuildContext context, String title, bool isDone) {
    return CheckboxListTile(
      value: isDone,
      onChanged: null,
      title: Text(
        title,
        style: TextStyle(
          decoration: isDone ? TextDecoration.lineThrough : null,
          color: isDone ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5) : null,
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
