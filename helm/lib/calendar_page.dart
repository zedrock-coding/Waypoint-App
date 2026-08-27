import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'providers/task_provider.dart';
import 'models/unified_task.dart';
import 'widgets/task_item_card.dart';
import 'task_detail_page.dart';
import 'app_shell.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<UnifiedTask> _getEventsForDay(DateTime day, List<UnifiedTask> allTasks) {
    // Ensure we are comparing dates correctly by normalizing to midnight local time
    return allTasks.where((task) {
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate!.toLocal(), day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final allTasks = taskProvider.allTasksWithDueDates;
    final colorScheme = Theme.of(context).colorScheme;

    final selectedTasks = _selectedDay == null 
        ? allTasks 
        : _getEventsForDay(_selectedDay!, allTasks);

    return AppShell(
      title: 'Calendar',
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
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
                setState(() {
                  _calendarFormat = format;
                });
              },
              eventLoader: (day) => _getEventsForDay(day, allTasks),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.3), shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: Colors.tealAccent.shade400, shape: BoxShape.circle),
                markersMaxCount: 3,
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ActionChip(
                  label: const Text('All Tasks'),
                  onPressed: () => setState(() => _selectedDay = null),
                  backgroundColor: _selectedDay == null ? colorScheme.primaryContainer : null,
                ),
                const SizedBox(width: 8),
                if (_selectedDay != null)
                  Text(
                    'Tasks for ${_selectedDay!.day}/${_selectedDay!.month}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: selectedTasks.isEmpty
                ? const Center(child: Text('No tasks for this date.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: selectedTasks.length,
                    itemBuilder: (context, index) {
                      final task = selectedTasks[index];
                      return TaskItemCard(
                        task: task,
                        index: index,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
                        ),
                        onToggle: () => taskProvider.toggleTask(task),
                        onDismiss: (_) => taskProvider.deleteTask(task.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
