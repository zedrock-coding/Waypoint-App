import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/unified_task.dart';
import 'models/hive_models.dart' as hive_model;
import 'widgets/task_form_utils.dart';

class TaskDetailScreen extends StatelessWidget {
  final UnifiedTask task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: TaskDetailContent(task: task),
    );
  }
}

class TaskDetailContent extends StatelessWidget {
  final UnifiedTask task;
  final VoidCallback? onClose;
  final bool useHero;

  const TaskDetailContent({
    super.key, 
    required this.task, 
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
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onClose != null) const SizedBox(height: 32),
                    Text(
                      task.title,
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
                        task.description.isNotEmpty ? task.description : 'No description provided.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildInfoRow(
                        context, 
                        icon: Icons.access_time, 
                        label: 'Date', 
                        value: DateFormat.yMMMMd().add_jm().format(task.dateTime),
                      ),
                      
                      const SizedBox(height: 40),
                      _buildSectionTitle(context, 'Sub-tasks'),
                      const SizedBox(height: 16),
                      const Center(child: Text('Coming Soon')),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    showAddTaskForm(context, taskToEdit: task);
                  },
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
        tag: 'task_card_${task.id}',
        child: content,
      );
    }
    return content;
  }

  Widget _buildTags(BuildContext context) {
    String? categoryName;
    if (task.categoryId != null) {
      final box = Hive.box<hive_model.Category>('categories');
      categoryName = box.get(task.categoryId)?.name;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPill(context, task.priority.name.toUpperCase(), isPriority: true),
        if (categoryName != null) _buildPill(context, categoryName.toUpperCase()),
        if (!task.isLocal) _buildPill(context, 'CLOUD'),
      ],
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.5))),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildPill(BuildContext context, String label, {bool isPriority = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPriority ? colorScheme.primary : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPriority ? colorScheme.onPrimary : colorScheme.onSecondaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
