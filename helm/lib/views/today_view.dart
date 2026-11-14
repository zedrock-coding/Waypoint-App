import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/unified_task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/task_item_card.dart';

enum TodayFilter { all, recurring, highPriority, completed }

class TodayView extends StatefulWidget {
  final Function(UnifiedTask) onTaskTap;

  const TodayView({super.key, required this.onTaskTap});

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  TodayFilter _currentFilter = TodayFilter.all;
  bool _completedCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final activeTasks = taskProvider.tasksForToday;
    final completedTasks = taskProvider.completedTasksToday;

    final urgentCount = activeTasks.where((t) => t.priority == Priority.high).length;
    final recurringCount = activeTasks.where((t) => t.isRecurring || t.recurrenceRule != null).length;

    // Filter tasks based on selected chip
    List<UnifiedTask> filteredTasks = activeTasks;
    if (_currentFilter == TodayFilter.recurring) {
      filteredTasks = activeTasks.where((t) => t.isRecurring || t.recurrenceRule != null).toList();
    } else if (_currentFilter == TodayFilter.highPriority) {
      filteredTasks = activeTasks.where((t) => t.priority == Priority.high).toList();
    } else if (_currentFilter == TodayFilter.completed) {
      filteredTasks = completedTasks.isNotEmpty ? completedTasks : taskProvider.allCompletedTasks;
    }

    final todayFormatted = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 896), // max-w-4xl
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          children: [
            // 1. Header Information Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "TODAY'S FOCUS",
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
                        todayFormatted,
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Active Worklist',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${activeTasks.length} active tasks',
                        style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                      if (urgentCount > 0) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('•', style: TextStyle(color: AppTheme.surfaceVariant)),
                        ),
                        Text(
                          '$urgentCount urgent',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.priorityUrgent,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Filter Chips Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Active', TodayFilter.all, activeTasks.length),
                        const SizedBox(width: 6),
                        _buildFilterChip('Recurring', TodayFilter.recurring, recurringCount),
                        const SizedBox(width: 6),
                        _buildFilterChip('High Priority', TodayFilter.highPriority, urgentCount),
                        const SizedBox(width: 6),
                        _buildFilterChip('Completed', TodayFilter.completed, completedTasks.length),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.surfaceVariant, height: 1),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Active Tasks List
            if (filteredTasks.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 36, color: AppTheme.mint),
                      const SizedBox(height: 8),
                      Text(
                        _currentFilter == TodayFilter.all
                            ? 'All caught up for today!'
                            : 'No tasks matching this filter.',
                        style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...filteredTasks.asMap().entries.map((entry) {
                final task = entry.value;
                final index = entry.key;
                return TaskItemCard(
                  key: ValueKey('today_${task.id}'),
                  task: task,
                  index: index,
                  onTap: () => widget.onTaskTap(task),
                  onToggle: () => taskProvider.toggleTask(task),
                  onDismiss: (_) => taskProvider.deleteTask(task.id, taskBackup: task),
                );
              }),
            ],

            // 3. Completed Section
            if (completedTasks.isNotEmpty && _currentFilter != TodayFilter.completed) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const Divider(color: AppTheme.surfaceVariant, height: 1),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setState(() => _completedCollapsed = !_completedCollapsed),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.mint),
                              const SizedBox(width: 6),
                              Text(
                                'Completed Today (${completedTasks.length} tasks)',
                                style: AppTheme.monoStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _completedCollapsed
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            size: 18,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    if (!_completedCollapsed) ...[
                      const SizedBox(height: 8),
                      ...completedTasks.asMap().entries.map((entry) {
                        final task = entry.value;
                        return TaskItemCard(
                          key: ValueKey('completed_${task.id}'),
                          task: task,
                          index: entry.key,
                          onTap: () => widget.onTaskTap(task),
                          onToggle: () => taskProvider.toggleTask(task),
                          onDismiss: (_) => taskProvider.deleteTask(task.id, taskBackup: task),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, TodayFilter filter, int count) {
    final isSelected = _currentFilter == filter;
    return InkWell(
      onTap: () => setState(() => _currentFilter = filter),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppTheme.mint.withValues(alpha: 0.5) : AppTheme.surfaceVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? AppTheme.mint : AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.mint.withValues(alpha: 0.2) : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '$count',
                style: AppTheme.monoStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.mint : AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
