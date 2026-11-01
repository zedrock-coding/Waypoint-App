import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/unified_task.dart';
import 'providers/task_provider.dart';
import 'services/supabase_service.dart';
import 'services/ai_service.dart';
import 'models/hive_models.dart' as hive_model;
import 'package:hive_flutter/hive_flutter.dart';

class AddEventPage extends StatefulWidget {
  final UnifiedTask? taskToEdit;
  final String? initialCategory;
  final String? initialCommunityId;
  final bool isDialog;

  const AddEventPage({
    super.key,
    this.taskToEdit,
    this.initialCategory,
    this.initialCommunityId,
    this.isDialog = false,
  });

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  late Priority _selectedPriority;
  late Status _selectedStatus;

  List<hive_model.Category> _availableHiveCategories = [];
  final List<String> _selectedCategoryIds = [];
  final List<String> _selectedAssigneeIds = [];
  final List<TextEditingController> _subtaskControllers = [];

  /// Subtasks as loaded from the task being edited, used to restore
  /// `is_completed` (and any other metadata) when the list is rebuilt on save.
  final List<Map<String, dynamic>> _originalSubtasks = [];
  bool _hasUnsavedChanges = false;

  String? _selectedDestination;
  List<Map<String, dynamic>> _userCommunities = [];
  List<Map<String, dynamic>> _communityMembers = [];
  bool _isUserLoggedIn = false;
  bool _isLoadingMembers = false;
  bool _isGeneratingSubtasks = false;

  @override
  void initState() {
    super.initState();
    _isUserLoggedIn = Supabase.instance.client.auth.currentUser != null;

    if (widget.initialCommunityId != null) {
      _selectedDestination = widget.initialCommunityId;
    } else if (widget.taskToEdit != null) {
      _selectedDestination =
          widget.taskToEdit!.communityId ?? (_isUserLoggedIn ? null : 'local');
    } else {
      _selectedDestination = _isUserLoggedIn ? null : 'local';
    }

    _titleController = TextEditingController(
      text: widget.taskToEdit?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.taskToEdit?.description ?? '',
    );

    if (widget.taskToEdit != null) {
      _selectedAssigneeIds.addAll(widget.taskToEdit!.assignees);
      _selectedCategoryIds.addAll(widget.taskToEdit!.categoryIds);
      for (var sub in widget.taskToEdit!.subtasks) {
        final copy = Map<String, dynamic>.from(sub);
        _originalSubtasks.add(copy);
        _subtaskControllers.add(
          TextEditingController(text: copy['title']?.toString() ?? ''),
        );
      }
    }

    // Only a real due date counts. Falling back to `dateTime` (which is
    // `createdAt` when no deadline exists) meant every edit re-stamped a due
    // date the user had never set.
    _selectedDate = widget.taskToEdit?.dueDate;
    _selectedTime = widget.taskToEdit?.dueDate != null
        ? TimeOfDay.fromDateTime(widget.taskToEdit!.dueDate!)
        : null;
    _selectedPriority = widget.taskToEdit?.priority ?? Priority.medium;
    _selectedStatus = widget.taskToEdit?.status ?? Status.toDo;

    _loadHiveCategories();
    _loadSupabaseCommunities();
    _loadCommunityMembers();

    _titleController.addListener(_markChanges);
    _descriptionController.addListener(_markChanges);
  }

  Future<void> _loadHiveCategories() async {
    final box = Hive.box<hive_model.Category>('categories');
    setState(() {
      _availableHiveCategories = box.values.toList();
    });
  }

  Future<void> _loadSupabaseCommunities() async {
    final communities = await SupabaseService().fetchUserCommunities();
    setState(() {
      _userCommunities = communities;
    });
  }

  Future<void> _loadCommunityMembers() async {
    if (_selectedDestination == null || _selectedDestination == 'local') {
      setState(() {
        _communityMembers = [];
        _selectedAssigneeIds.clear();
      });
      return;
    }

    setState(() => _isLoadingMembers = true);
    try {
      final members = await SupabaseService().getCommunityMembers(
        _selectedDestination!,
      );
      setState(() {
        _communityMembers = members;
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
    } finally {
      setState(() => _isLoadingMembers = false);
    }
  }

  void _markChanges() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _addSubtask() {
    setState(() {
      _subtaskControllers.add(TextEditingController());
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _decomposeSubtasksWithAi() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a task title or description first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isGeneratingSubtasks = true);
    try {
      final aiService = context.read<AiService>();
      final subtasks = await aiService.generateSubtasks(
        title: title.isNotEmpty ? title : description,
        description: description,
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
            _hasUnsavedChanges = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI generated ${subtasks.length} subtask milestones!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No subtasks could be decomposed from this task.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AI subtask generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate subtasks: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSubtasks = false);
      }
    }
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtaskControllers[index].dispose();
      _subtaskControllers.removeAt(index);
      _hasUnsavedChanges = true;
    });
  }

  /// Rebuilds the subtask payload while keeping the completion state of items
  /// that survived the edit.
  ///
  /// The save path used to hard-code `is_completed: false`, so opening a task,
  /// touching anything and saving silently reset every ticked subtask. Items are
  /// matched by trimmed title (case-insensitive); a renamed or new item starts
  /// unchecked, which is the only defensible answer without stable ids.
  List<Map<String, dynamic>> _buildSubtasks() {
    final Map<String, List<Map<String, dynamic>>> pool = {};
    for (final sub in _originalSubtasks) {
      final key = (sub['title']?.toString() ?? '').trim().toLowerCase();
      pool.putIfAbsent(key, () => []).add(sub);
    }

    final List<Map<String, dynamic>> result = [];
    for (final controller in _subtaskControllers) {
      final title = controller.text.trim();
      if (title.isEmpty) continue;

      final bucket = pool[title.toLowerCase()];
      if (bucket != null && bucket.isNotEmpty) {
        final match = Map<String, dynamic>.from(bucket.removeAt(0));
        match['title'] = title;
        result.add(match);
      } else {
        result.add({'title': title, 'is_completed': false});
      }
    }
    return result;
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      try {
        final taskProvider = context.read<TaskProvider>();
        final List<Map<String, dynamic>> subtasks = _buildSubtasks();

        // Combine date and time. Null means "no due date", which is a real
        // state: passing null through clears the deadline and cancels reminders.
        DateTime? finalDueAt;
        if (_selectedDate != null) {
          finalDueAt = _selectedTime == null
              ? _selectedDate
              : DateTime(
                  _selectedDate!.year,
                  _selectedDate!.month,
                  _selectedDate!.day,
                  _selectedTime!.hour,
                  _selectedTime!.minute,
                );
        }

        if (widget.taskToEdit != null) {
          // Preserve completion status for existing subtasks if possible
          // In a real app we'd map old to new, for now we just take the text
          await taskProvider.updateTask(
            id: widget.taskToEdit!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            categoryIds: _selectedCategoryIds,
            assignees: _selectedAssigneeIds,
            subtasks: subtasks,
            priority: _selectedPriority,
            status: _selectedStatus,
            dueAt: finalDueAt,
          );
        } else {
          final String? communityId =
              (_selectedDestination != null && _selectedDestination != 'local')
              ? _selectedDestination
              : null;

          final bool isLocalOnly = _selectedDestination == 'local';

          await taskProvider.addTask(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            communityId: communityId,
            categoryIds: _selectedCategoryIds,
            assignees: _selectedAssigneeIds,
            subtasks: subtasks,
            priority: _selectedPriority,
            status: _selectedStatus,
            isLocalOnly: isLocalOnly,
            dueAt: finalDueAt,
          );
        }

        _hasUnsavedChanges = false;
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskToEdit != null;

    Widget formContent = Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: widget.isDialog,
        padding: const EdgeInsets.only(bottom: 100), // Clear FAB and buttons
        children: [
          _buildTextField(
            controller: _titleController,
            label: 'Title',
            validator: (v) => v?.isEmpty ?? true ? 'Enter title' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildStatusPriorityRow(),
          const SizedBox(height: 16),
          _buildDestinationSelector(),
          const SizedBox(height: 16),
          if (_selectedDestination != null && _selectedDestination != 'local')
            _buildAssigneeSelector(),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const Divider(height: 32),
          _buildCategorySelection(),
          const Divider(height: 32),
          _buildSubtaskSection(),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _saveTask,
            child: Text(isEditing ? 'Update Task' : 'Save Task'),
          ),
        ],
      ),
    );

    if (widget.isDialog) {
      return _buildDialogWrapper(isEditing, formContent);
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: SafeArea(
        top: true,
        child: Scaffold(
          appBar: AppBar(title: Text(isEditing ? 'Edit Task' : 'Add New Task')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: formContent,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _buildStatusPriorityRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Status>(
            initialValue: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: Status.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(_formatStatus(s).toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _selectedStatus = v!;
              _hasUnsavedChanges = true;
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<Priority>(
            initialValue: _selectedPriority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              border: OutlineInputBorder(),
            ),
            items: Priority.values
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _selectedPriority = v!;
              _hasUnsavedChanges = true;
            }),
          ),
        ),
      ],
    );
  }

  String _formatStatus(Status s) {
    if (s == Status.inProgress) return 'In Progress';
    return s.name;
  }

  Widget _buildAssigneeSelector() {
    if (_isLoadingMembers) {
      return const Center(child: LinearProgressIndicator());
    }
    if (_communityMembers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign to Members:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _communityMembers.map((member) {
            final String id = member['user_id'];
            final String name =
                member['full_name'] ?? 'User ${id.substring(0, 4)}';
            final isSelected = _selectedAssigneeIds.contains(id);

            return FilterChip(
              label: Text(name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _hasUnsavedChanges = true;
                  if (selected) {
                    _selectedAssigneeIds.add(id);
                  } else {
                    _selectedAssigneeIds.remove(id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    final hasDueDate = _selectedDate != null;
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          title: Text(
            hasDueDate
                ? "Due Date: ${DateFormat.yMMMd().format(_selectedDate!)}"
                : "Due Date: None",
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasDueDate)
                IconButton(
                  tooltip: 'Clear due date',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _selectedDate = null;
                    _selectedTime = null;
                    _hasUnsavedChanges = true;
                  }),
                ),
              const Icon(Icons.calendar_today),
            ],
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                _hasUnsavedChanges = true;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        ListTile(
          enabled: hasDueDate,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          title: Text(
            "Time: ${_selectedTime != null ? _selectedTime!.format(context) : (hasDueDate ? 'None (All Day)' : 'Set a date first')}",
          ),
          trailing: const Icon(Icons.access_time),
          onTap: hasDueDate
              ? () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedTime = picked;
                      _hasUnsavedChanges = true;
                    });
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildDestinationSelector() {
    final List<String?> validIds = [
      null,
      'local',
      ..._userCommunities.map((c) => c['id'].toString()),
    ];
    final String? effectiveValue = validIds.contains(_selectedDestination)
        ? _selectedDestination
        : 'local';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Destination:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          key: ValueKey('destination_$effectiveValue'),
          initialValue: effectiveValue,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
          items: [
            if (_isUserLoggedIn)
              const DropdownMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done_outlined,
                      size: 18,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Text('Personal (Cloud Sync)'),
                  ],
                ),
              ),
            const DropdownMenuItem(
              value: 'local',
              child: Row(
                children: [
                  Icon(Icons.smartphone_rounded, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Device Only (Offline)'),
                ],
              ),
            ),
            ..._userCommunities.map(
              (comm) => DropdownMenuItem(
                value: comm['id'].toString(),
                child: Row(
                  children: [
                    const Icon(Icons.hub_rounded, size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text('Community: ${comm['name']}'),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (val) {
            setState(() {
              _selectedDestination = val;
              _hasUnsavedChanges = true;
            });
            _loadCommunityMembers();
          },
        ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Apply Categories (Tags):',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _availableHiveCategories.map((cat) {
            final String catId = cat.id ?? '';
            final isSelected = _selectedCategoryIds.contains(catId);
            return FilterChip(
              label: Text(cat.name ?? 'Unnamed'),
              selected: isSelected,
              onSelected: (selected) => setState(() {
                _hasUnsavedChanges = true;
                if (selected) {
                  _selectedCategoryIds.add(catId);
                } else {
                  _selectedCategoryIds.remove(catId);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubtaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Sub-tasks',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              key: const ValueKey('ai_decompose_subtasks_button'),
              onPressed: _isGeneratingSubtasks ? null : _decomposeSubtasksWithAi,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _isGeneratingSubtasks
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF88C0A4),
                      ),
                    )
                  : const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Color(0xFF88C0A4),
                    ),
              label: Text(
                _isGeneratingSubtasks ? 'Decomposing...' : 'AI Subtasks',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF88C0A4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _addSubtask,
              icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
            ),
          ],
        ),
        ...List.generate(_subtaskControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Task ${index + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeSubtask(index),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDialogWrapper(bool isEditing, Widget content) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        isEditing ? 'Edit Task' : 'Add New Task',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          final shouldClose = await _onWillPop();
                          if (shouldClose && mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Flexible(child: content),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text('Discard changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('NO'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('YES'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (var c in _subtaskControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
