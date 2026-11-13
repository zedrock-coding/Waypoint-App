import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/unified_task.dart';
import '../providers/task_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

void showTaskCreationDrawer(BuildContext context, {UnifiedTask? taskToEdit}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      final isDesktop = MediaQuery.of(ctx).size.width >= 768;
      return Align(
        alignment: isDesktop ? Alignment.centerRight : Alignment.bottomCenter,
        child: TaskCreationDrawer(taskToEdit: taskToEdit),
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final isDesktop = MediaQuery.of(ctx).size.width >= 768;
      final begin = isDesktop ? const Offset(1.0, 0.0) : const Offset(0.0, 1.0);
      return SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}

class TaskCreationDrawer extends StatefulWidget {
  final UnifiedTask? taskToEdit;

  const TaskCreationDrawer({super.key, this.taskToEdit});

  @override
  State<TaskCreationDrawer> createState() => _TaskCreationDrawerState();
}

class _TaskCreationDrawerState extends State<TaskCreationDrawer> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<TextEditingController> _subtaskControllers = [];

  Priority _selectedPriority = Priority.high;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  String _selectedRecurrence = 'none';
  String _selectedWorkspace = 'Personal';

  bool _isGeneratingSubtasks = false;
  bool _titleError = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _descController.text = t.description;
      _selectedPriority = t.priority;
      final due = t.dueDate ?? t.dateTime;
      _selectedDate = due;
      _selectedTime = TimeOfDay(hour: due.hour, minute: due.minute);
      if (t.isRecurring && t.recurrenceRule != null) {
        _selectedRecurrence = t.recurrenceRule!.frequency;
      }
      for (final s in t.subtasks) {
        _subtaskControllers.add(TextEditingController(text: s['title']?.toString() ?? ''));
      }
    } else {
      _subtaskControllers.add(TextEditingController(text: 'Review architecture & data contracts'));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _aiDecompose() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty && desc.isEmpty) {
      setState(() => _titleError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a task title or description first')),
      );
      return;
    }

    setState(() => _isGeneratingSubtasks = true);
    try {
      final aiService = context.read<AiService>();
      final subtasks = await aiService.generateSubtasks(
        title: title.isNotEmpty ? title : desc,
        description: desc,
      );

      if (mounted) {
        if (subtasks.isNotEmpty) {
          setState(() {
            _subtaskControllers.removeWhere((c) {
              final empty = c.text.trim().isEmpty;
              if (empty) c.dispose();
              return empty;
            });
            for (final st in subtasks) {
              _subtaskControllers.add(TextEditingController(text: st));
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI decomposed ${subtasks.length} subtask milestones!'),
              backgroundColor: AppTheme.surfaceContainerHigh,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No subtasks could be decomposed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI decomposition: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSubtasks = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _commit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }

    final dueDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final subtasksList = _subtaskControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => {'id': UniqueKey().toString(), 'title': t, 'is_completed': false})
        .toList();

    final isRecurring = _selectedRecurrence != 'none';
    RecurrenceRule? rule;
    if (isRecurring) {
      rule = RecurrenceRule(frequency: _selectedRecurrence, interval: 1);
    }

    final taskProvider = context.read<TaskProvider>();

    if (widget.taskToEdit != null) {
      // Update existing task
      final edited = widget.taskToEdit!;
      await taskProvider.updateTask(
        id: edited.id,
        title: title,
        description: _descController.text.trim(),
        dueAt: dueDateTime,
        priority: _selectedPriority,
        subtasks: subtasksList,
        isRecurring: isRecurring,
        recurrenceRule: rule,
      );
    } else {
      // Add new task
      await taskProvider.addTask(
        title: title,
        description: _descController.text.trim(),
        dueAt: dueDateTime,
        priority: _selectedPriority,
        categoryIds: [_selectedWorkspace.toLowerCase()],
        subtasks: subtasksList,
        isRecurring: isRecurring,
        recurrenceRule: rule,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.taskToEdit != null ? 'Task updated' : 'Task created: $title'),
          backgroundColor: AppTheme.surfaceContainerHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final width = isDesktop ? 480.0 : MediaQuery.of(context).size.width;
    final height = isDesktop ? MediaQuery.of(context).size.height : MediaQuery.of(context).size.height * 0.92;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(
            left: BorderSide(color: AppTheme.surfaceVariant, width: 1),
            top: isDesktop ? BorderSide.none : BorderSide(color: AppTheme.surfaceVariant, width: 1),
          ),
          borderRadius: isDesktop ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(8)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainer,
                border: Border(bottom: BorderSide(color: AppTheme.surfaceVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.taskToEdit != null ? 'Edit Task' : 'New Task / Checkpoint',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create scheduled task or recurring cadence',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppTheme.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Title Input
                  Text(
                    'TASK TITLE *',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _titleError ? AppTheme.priorityUrgent : AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
                    onChanged: (_) {
                      if (_titleError) setState(() => _titleError = false);
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g., Deliver WES Foundation quarterly ledger audit',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: _titleError ? AppTheme.priorityUrgent : AppTheme.surfaceVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: AppTheme.mint, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Notes / Description
                  Text(
                    'NOTES / ACCEPTANCE CRITERIA',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Add context, sub-deliverables, or key milestones...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLowest,
                      contentPadding: const EdgeInsets.all(12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: AppTheme.surfaceVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: AppTheme.mint, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Priority Selector
                  Text(
                    'PRIORITY LEVEL',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildPriorityButton('Urgent', Priority.high, AppTheme.priorityUrgent),
                      const SizedBox(width: 8),
                      _buildPriorityButton('High', Priority.medium, AppTheme.priorityHigh),
                      const SizedBox(width: 8),
                      _buildPriorityButton('Med', Priority.low, AppTheme.priorityMedium),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Date & Recurrence Row
                  Row(
                    children: [
                      // Target Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARGET DATE',
                              style: AppTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.surfaceVariant),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.mint),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('MMM d, y').format(_selectedDate),
                                      style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TIME',
                              style: AppTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.surfaceVariant),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.mint),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedTime.format(context),
                                      style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.onSurface),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Recurrence Cadence Dropdown
                  Text(
                    'RECURRENCE CADENCE',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.surfaceVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRecurrence,
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceContainerHigh,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.onSurfaceVariant),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('One-time Task')),
                          DropdownMenuItem(value: 'daily', child: Text('Daily (Every Day)')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly (7-Day Cycle)')),
                          DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly (14-Day Cycle)')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRecurrence = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Workspace / Group Selector
                  Text(
                    'WORKSPACE / GROUP',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildWorkspaceChip('Personal', AppTheme.mint),
                      _buildWorkspaceChip('Engineering', AppTheme.priorityHigh),
                      _buildWorkspaceChip('WES Foundation', AppTheme.mint),
                      _buildWorkspaceChip('Eureka! Showcase', AppTheme.priorityUrgent),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Checkpoints & AI Decompose Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ATOMIC CHECKPOINTS / SUBTASKS',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      // AI DECOMPOSE BUTTON
                      TextButton.icon(
                        onPressed: _isGeneratingSubtasks ? null : _aiDecompose,
                        icon: _isGeneratingSubtasks
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mint),
                              )
                            : const Icon(Icons.auto_awesome, size: 14, color: AppTheme.mint),
                        label: Text(
                          _isGeneratingSubtasks ? 'Decomposing...' : '✨ AI Decompose',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mint,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          backgroundColor: AppTheme.mint.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Subtasks input rows
                  ..._subtaskControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: AppTheme.surfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Checkpoint description...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceContainerLowest,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: AppTheme.surfaceVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: AppTheme.mint),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.outline),
                            hoverColor: AppTheme.priorityUrgent.withValues(alpha: 0.1),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () {
                              setState(() {
                                controller.dispose();
                                _subtaskControllers.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add Checkpoint button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _subtaskControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 14, color: AppTheme.mint),
                      label: Text(
                        'Add checkpoint',
                        style: AppTheme.monoStyle(fontSize: 11, color: AppTheme.mint),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 3. Footer Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainer,
                border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.onSurface,
                      side: const BorderSide(color: AppTheme.surfaceVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _commit,
                    icon: const Icon(Icons.check, size: 16, color: AppTheme.onMint),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.taskToEdit != null ? 'Save Changes' : 'Create Task',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onMint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.onMint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            '⌘↵',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onMint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mint,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityButton(String label, Priority p, Color color) {
    final isSelected = _selectedPriority == p;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPriority = p),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? color : AppTheme.surfaceVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.monoStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? color : AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceChip(String label, Color dotColor) {
    final isSelected = _selectedWorkspace == label;
    return InkWell(
      onTap: () => setState(() => _selectedWorkspace = label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.mint.withValues(alpha: 0.15) : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppTheme.mint : AppTheme.surfaceVariant,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.monoStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.mint : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
