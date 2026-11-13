import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/unified_task.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/task_item_card.dart';

class ScheduleView extends StatefulWidget {
  final Function(UnifiedTask) onTaskTap;

  const ScheduleView({super.key, required this.onTaskTap});

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<UnifiedTask> _getEventsForDay(DateTime day, List<UnifiedTask> allTasks) {
    return allTasks.where((task) {
      final due = (task.dueDate ?? task.dateTime).toLocal();
      return isSameDay(due, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final allTasks = taskProvider.allTasksWithDueDates;

    final selectedTasks = _selectedDay == null
        ? allTasks
        : _getEventsForDay(_selectedDay!, allTasks);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 896),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 90),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'TIMELINE & SCHEDULE',
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
                        'Monthly Overview',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Schedule & Calendar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.surfaceVariant, height: 1),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Calendar Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.surfaceVariant),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                  eventLoader: (day) => _getEventsForDay(day, allTasks),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.mint,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    selectedTextStyle: const TextStyle(
                      color: AppTheme.onMint,
                      fontWeight: FontWeight.bold,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: 0.2),
                      shape: BoxShape.rectangle,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      border: Border.all(color: AppTheme.mint),
                    ),
                    todayTextStyle: const TextStyle(
                      color: AppTheme.mint,
                      fontWeight: FontWeight.bold,
                    ),
                    defaultTextStyle: const TextStyle(color: AppTheme.onSurface),
                    weekendTextStyle: const TextStyle(color: AppTheme.onSurfaceVariant),
                    outsideTextStyle: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3)),
                    markerDecoration: const BoxDecoration(
                      color: AppTheme.mint,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                    leftChevronIcon: const Icon(Icons.chevron_left, color: AppTheme.onSurfaceVariant),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: AppTheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Chips / Date header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _selectedDay = null),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _selectedDay == null ? AppTheme.mint.withValues(alpha: 0.15) : AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _selectedDay == null ? AppTheme.mint : AppTheme.surfaceVariant,
                        ),
                      ),
                      child: Text(
                        'All Tasks (${allTasks.length})',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedDay == null ? AppTheme.mint : AppTheme.onSurfaceVariant,
                          fontWeight: _selectedDay == null ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedDay != null)
                    Text(
                      'Tasks for ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                      style: AppTheme.monoStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (selectedTasks.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Center(
                  child: Text(
                    'No tasks scheduled for this day.',
                    style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ),
              ),
            ] else ...[
              ...selectedTasks.asMap().entries.map((entry) {
                final task = entry.value;
                final index = entry.key;
                return TaskItemCard(
                  key: ValueKey('sched_${task.id}'),
                  task: task,
                  index: index,
                  onTap: () => widget.onTaskTap(task),
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
