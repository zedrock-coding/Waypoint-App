import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'models/event.dart';
import 'models/category.dart';

class AddEventPage extends StatefulWidget {
  final Isar isar;
  final Event? eventToEdit;
  final String? initialCategory;
  final bool isDialog;

  const AddEventPage({
    super.key, 
    required this.isar, 
    this.eventToEdit, 
    this.initialCategory,
    this.isDialog = false,
  });

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final TextEditingController _assigneeInputController = TextEditingController();
  final FocusNode _assigneeFocusNode = FocusNode();
  late DateTime _selectedDate;
  
  late Status _selectedStatus;
  late Priority _selectedPriority;
  
  List<Category> _availableCategories = [];
  final List<Category> _selectedCategories = [];
  final List<String> _assignees = [];
  bool _allowMultiple = true;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.eventToEdit?.title ?? '');
    _descriptionController = TextEditingController(text: widget.eventToEdit?.description ?? '');
    if (widget.eventToEdit != null) {
      _assignees.addAll(widget.eventToEdit!.assignees);
    }
    _selectedDate = widget.eventToEdit?.dateTime ?? DateTime.now();
    _selectedStatus = widget.eventToEdit?.status ?? Status.toDo;
    _selectedPriority = widget.eventToEdit?.priority ?? Priority.medium;
    
    _loadCategories();

    // Listen for changes
    _titleController.addListener(_markChanges);
    _descriptionController.addListener(_markChanges);
  }

  void _markChanges() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.isar.categorys.where().sortByName().findAll();
      setState(() {
        _availableCategories = categories;
        
        if (widget.eventToEdit != null) {
          widget.eventToEdit!.categories.loadSync();
          _selectedCategories.addAll(widget.eventToEdit!.categories);
          if (_selectedCategories.length > 1) {
            _allowMultiple = true;
          }
        } else if (widget.initialCategory != null) {
          final match = categories.where((c) => c.name == widget.initialCategory).firstOrNull;
          if (match != null) {
            _selectedCategories.add(match);
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  void _addAssignee(String name) {
    final cleanName = name.trim().replaceAll(',', '');
    if (cleanName.isNotEmpty && !_assignees.contains(cleanName)) {
      setState(() {
        _assignees.add(cleanName);
        _assigneeInputController.clear();
        _hasUnsavedChanges = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _assigneeFocusNode.requestFocus();
      });
    } else {
      _assigneeInputController.clear();
      _assigneeFocusNode.requestFocus();
    }
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      try {
        final event = widget.eventToEdit ?? Event();
        event.title = _titleController.text.trim();
        event.description = _descriptionController.text.trim();
        event.dateTime = _selectedDate;
        event.status = _selectedStatus;
        event.priority = _selectedPriority;
        event.assignees = List.from(_assignees);

        if (_selectedCategories.isEmpty) {
          final generalCat = await widget.isar.categorys.filter().nameEqualTo('General').findFirst();
          if (generalCat != null) {
            _selectedCategories.add(generalCat);
          }
        }

        await widget.isar.writeTxn(() async {
          await widget.isar.events.put(event);
          event.categories.clear();
          event.categories.addAll(_selectedCategories);
          await event.categories.save();
        });

        _hasUnsavedChanges = false;
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('CRITICAL ERROR SAVING EVENT: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatStatus(Status status) {
    if (status == Status.inProgress) return 'In Progress';
    return status.name[0].toUpperCase() + status.name.substring(1);
  }

  Widget _buildStatusIcon(Status status) {
    IconData iconData;
    Color color;
    Key key;

    switch (status) {
      case Status.toDo:
        iconData = Icons.radio_button_unchecked;
        color = Colors.grey;
        key = const ValueKey('todo');
        break;
      case Status.inProgress:
        iconData = Icons.published_with_changes; 
        color = Theme.of(context).colorScheme.primary;
        key = const ValueKey('inprogress');
        break;
      case Status.done:
        iconData = Icons.check_circle;
        color = Colors.green;
        key = const ValueKey('done');
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: Icon(iconData, color: color, key: key, size: 20),
    );
  }

  void _showAddSubtaskSheet() {
    final subtaskTitleController = TextEditingController();
    Status subtaskStatus = Status.toDo;
    Priority subtaskPriority = Priority.medium;
    List<String> subtaskAssignees = [];
    final subtaskAssigneeInputController = TextEditingController();
    final subtaskAssigneeFocusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Sub-task', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('subtask_title_field'),
                controller: subtaskTitleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Status>(
                      initialValue: subtaskStatus,
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                      items: Status.values.map((s) => DropdownMenuItem(value: s, child: Text(_formatStatus(s).toUpperCase()))).toList(),
                      onChanged: (val) => setModalState(() => subtaskStatus = val!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<Priority>(
                      initialValue: subtaskPriority,
                      decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                      items: Priority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                      onChanged: (val) => setModalState(() => subtaskPriority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('subtask_assignee_field'),
                controller: subtaskAssigneeInputController,
                focusNode: subtaskAssigneeFocusNode,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Add Assignee', 
                  hintText: 'Type and press Enter or comma',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  if (val.endsWith(',')) {
                    final name = val.substring(0, val.length - 1).trim();
                    if (name.isNotEmpty) {
                      setModalState(() {
                        subtaskAssignees.add(name);
                        subtaskAssigneeInputController.clear();
                      });
                      subtaskAssigneeFocusNode.requestFocus();
                    }
                  }
                },
                onSubmitted: (val) {
                  final name = val.trim();
                  if (name.isNotEmpty) {
                    setModalState(() {
                      subtaskAssignees.add(name);
                      subtaskAssigneeInputController.clear();
                    });
                    subtaskAssigneeFocusNode.requestFocus();
                  }
                },
              ),
              if (subtaskAssignees.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: subtaskAssignees.map((a) => Chip(
                    label: Text(a, style: const TextStyle(fontSize: 10)),
                    onDeleted: () => setModalState(() => subtaskAssignees.remove(a)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () async {
                  if (subtaskTitleController.text.isNotEmpty) {
                    final subtask = Event()
                      ..title = subtaskTitleController.text.trim()
                      ..description = ''
                      ..dateTime = _selectedDate
                      ..status = subtaskStatus
                      ..priority = subtaskPriority
                      ..assignees = subtaskAssignees;
                    
                    subtask.parent.value = widget.eventToEdit;

                    await widget.isar.writeTxn(() async {
                      await widget.isar.events.put(subtask);
                      await subtask.parent.save();
                    });
                    
                    if (context.mounted) Navigator.pop(context);
                    setState(() {}); 
                  }
                },
                child: const Text('Add Sub-task'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to discard your changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP EDITING'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DISCARD', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;

    Widget formContent = Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: widget.isDialog,
        physics: widget.isDialog ? const ClampingScrollPhysics() : null,
        children: [
          TextFormField(
            key: const ValueKey('main_title_field'),
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('main_description_field'),
            controller: _descriptionController,
            focusNode: FocusNode(debugLabel: 'description'),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Status>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: Status.values.map((s) => DropdownMenuItem(
                    value: s, 
                    child: Text(_formatStatus(s).toUpperCase()),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedStatus = val!;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<Priority>(
                  initialValue: _selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                  items: Priority.values.map((p) => DropdownMenuItem(
                    value: p, 
                    child: Text(p.name.toUpperCase()),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPriority = val!;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('main_assignee_field'),
                controller: _assigneeInputController,
                focusNode: _assigneeFocusNode..debugLabel = 'assignee',
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Add Assignee', 
                  hintText: 'Type name and press Enter or comma',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => _addAssignee(value),
                onChanged: (value) {
                  if (value.endsWith(',')) {
                    final name = value.substring(0, value.length - 1).trim();
                    if (name.isNotEmpty) {
                      _addAssignee(name);
                    } else {
                      _assigneeInputController.clear();
                    }
                  }
                },
              ),
              if (_assignees.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _assignees.map((name) => InputChip(
                    label: Text(name),
                    onDeleted: () {
                      setState(() {
                        _assignees.remove(name);
                        _hasUnsavedChanges = true;
                      });
                    },
                  )).toList(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            title: Text("Date: ${_selectedDate.toLocal()}".split(' ')[0]),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
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
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Allow Multiple Categories'),
            contentPadding: EdgeInsets.zero,
            value: _allowMultiple,
            onChanged: (val) {
              setState(() {
                _allowMultiple = val;
                _hasUnsavedChanges = true;
                if (!_allowMultiple && _selectedCategories.length > 1) {
                  final first = _selectedCategories.first;
                  _selectedCategories.clear();
                  _selectedCategories.add(first);
                }
              });
            },
          ),
          const Text('Select Categories:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: _availableCategories.map((cat) {
              final isSelected = _selectedCategories.any((element) => element.id == cat.id);
              return FilterChip(
                label: Text(cat.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _hasUnsavedChanges = true;
                    if (selected) {
                      if (!_allowMultiple) _selectedCategories.clear();
                      _selectedCategories.add(cat);
                    } else {
                      _selectedCategories.removeWhere((element) => element.id == cat.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          
          if (isEditing) ...[
            const Divider(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sub-tasks', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: _showAddSubtaskSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Sub-task'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<void>(
              stream: widget.isar.events.watchLazy(),
              builder: (context, snapshot) {
                return FutureBuilder<List<Event>>(
                  future: widget.isar.events.filter().parent((q) => q.idEqualTo(widget.eventToEdit!.id)).findAll(),
                  builder: (context, subtaskSnapshot) {
                    if (!subtaskSnapshot.hasData || subtaskSnapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: Text('No sub-tasks yet', style: TextStyle(color: Colors.grey))),
                      );
                    }
                    
                    final subtasks = subtaskSnapshot.data!;
                    return Column(
                      children: subtasks.map((st) {
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 32,
                                margin: const EdgeInsets.only(left: 16),
                                child: Stack(
                                  children: [
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        width: 2,
                                        height: double.infinity,
                                        color: Theme.of(context).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        height: 2,
                                        width: 16,
                                        color: Theme.of(context).colorScheme.outlineVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 8, right: 16),
                                  child: ListTile(
                                    dense: true,
                                    leading: _buildStatusIcon(st.status),
                                    title: Text(st.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: st.assignees.isEmpty 
                                      ? null 
                                      : Wrap(
                                          spacing: 4,
                                          children: st.assignees.map((a) => Text(
                                            a, 
                                            style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
                                          )).toList(),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _saveEvent,
            child: Text(isEditing ? 'Update Task' : 'Save Task'),
          ),
        ],
      ),
    );

    if (widget.isDialog) {
      return Dialog(
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
                      Text(isEditing ? 'Edit Task' : 'Add New Task', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Flexible(child: formContent),
                ],
              ),
            ),
          ),
        ),
      );
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
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () async {
            final shouldPop = await _onWillPop();
            if (shouldPop && context.mounted) {
              Navigator.pop(context);
            }
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            final focusLabel = FocusManager.instance.primaryFocus?.debugLabel ?? '';
            if (!focusLabel.contains('description') && !focusLabel.contains('assignee')) {
              _saveEvent();
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(isEditing ? 'Edit Task' : 'Add New Task'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: formContent,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeInputController.dispose();
    _assigneeFocusNode.dispose();
    super.dispose();
  }
}
