import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models/event.dart';
import 'models/category.dart';
import 'repositories/event_repository.dart';
import 'repositories/category_repository.dart';

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

    _titleController.addListener(_markChanges);
    _descriptionController.addListener(_markChanges);
  }

  void _markChanges() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _loadCategories() async {
    final categoryRepo = context.read<CategoryRepository>();
    final categories = await categoryRepo.getAllCategories();
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
  }

  void _addAssignee(String name) {
    final cleanName = name.trim().replaceAll(',', '');
    if (cleanName.isNotEmpty && !_assignees.contains(cleanName)) {
      setState(() {
        _assignees.add(cleanName);
        _assigneeInputController.clear();
        _hasUnsavedChanges = true;
      });
      _assigneeFocusNode.requestFocus();
    } else {
      _assigneeInputController.clear();
      _assigneeFocusNode.requestFocus();
    }
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      try {
        final eventRepo = context.read<EventRepository>();
        final categoryRepo = context.read<CategoryRepository>();
        
        final event = widget.eventToEdit ?? Event();
        event.title = _titleController.text.trim();
        event.description = _descriptionController.text.trim();
        event.dateTime = _selectedDate;
        event.status = _selectedStatus;
        event.priority = _selectedPriority;
        event.assignees = List.from(_assignees);

        if (_selectedCategories.isEmpty) {
          final generalCat = await categoryRepo.getCategoryByName('General');
          if (generalCat != null) _selectedCategories.add(generalCat);
        }

        await eventRepo.saveEvent(event, _selectedCategories);

        _hasUnsavedChanges = false;
        if (mounted && context.mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;

    Widget formContent = Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: widget.isDialog,
        children: [
          _buildTextField(controller: _titleController, label: 'Title', validator: (v) => v?.isEmpty ?? true ? 'Enter title' : null),
          const SizedBox(height: 16),
          _buildTextField(controller: _descriptionController, label: 'Description', maxLines: 2),
          const SizedBox(height: 16),
          _buildStatusPriorityRow(),
          const SizedBox(height: 16),
          _buildAssigneeInput(),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const Divider(height: 32),
          _buildCategorySelection(),
          if (isEditing) _buildSubtasksSection(),
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
      return _buildDialogWrapper(isEditing, formContent);
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop) {
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: SafeArea(
        top: true,
        child: Scaffold(
          appBar: AppBar(title: Text(isEditing ? 'Edit Task' : 'Add New Task')),
          body: Padding(padding: const EdgeInsets.all(16.0), child: formContent),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _buildStatusPriorityRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Status>(
            value: _selectedStatus,
            decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            items: Status.values.map((s) => DropdownMenuItem(value: s, child: Text(_formatStatus(s).toUpperCase()))).toList(),
            onChanged: (v) => setState(() { _selectedStatus = v!; _hasUnsavedChanges = true; }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<Priority>(
            value: _selectedPriority,
            decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
            items: Priority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
            onChanged: (v) => setState(() { _selectedPriority = v!; _hasUnsavedChanges = true; }),
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _assigneeInputController,
          focusNode: _assigneeFocusNode,
          decoration: const InputDecoration(labelText: 'Add Assignee', hintText: 'Type and press Enter', border: OutlineInputBorder()),
          onSubmitted: _addAssignee,
        ),
        if (_assignees.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _assignees.map((a) => InputChip(label: Text(a), onDeleted: () => setState(() { _assignees.remove(a); _hasUnsavedChanges = true; }))).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(4)),
      title: Text("Date: ${DateFormat.yMMMd().format(_selectedDate)}"),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2101));
        if (picked != null) setState(() { _selectedDate = picked; _hasUnsavedChanges = true; });
      },
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Allow Multiple Categories'),
          contentPadding: EdgeInsets.zero,
          value: _allowMultiple,
          onChanged: (v) => setState(() {
            _allowMultiple = v;
            if (!v && _selectedCategories.length > 1) {
              final first = _selectedCategories.first;
              _selectedCategories.clear();
              _selectedCategories.add(first);
            }
            _hasUnsavedChanges = true;
          }),
        ),
        const Text('Select Categories:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _availableCategories.map((cat) {
            final isSelected = _selectedCategories.any((c) => c.id == cat.id);
            return FilterChip(
              label: Text(cat.name),
              selected: isSelected,
              onSelected: (selected) => setState(() {
                _hasUnsavedChanges = true;
                if (selected) {
                  if (!_allowMultiple) _selectedCategories.clear();
                  _selectedCategories.add(cat);
                } else {
                  _selectedCategories.removeWhere((c) => c.id == cat.id);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubtasksSection() {
    final eventRepo = context.read<EventRepository>();
    return Column(
      children: [
        const Divider(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Sub-tasks', style: Theme.of(context).textTheme.titleLarge),
            TextButton.icon(onPressed: _showAddSubtaskSheet, icon: const Icon(Icons.add), label: const Text('Add Sub-task')),
          ],
        ),
        FutureBuilder<List<Event>>(
          future: eventRepo.getSubtasks(widget.eventToEdit!.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
            return Column(
              children: snapshot.data!.map((st) => ListTile(
                dense: true,
                title: Text(st.title),
                leading: Icon(st.status == Status.done ? Icons.check_circle : Icons.radio_button_unchecked, color: st.status == Status.done ? Colors.green : Colors.grey),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDialogWrapper(bool isEditing, Widget content) {
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
                Row(children: [
                  Text(isEditing ? 'Edit Task' : 'Add New Task', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 24),
                Flexible(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSubtaskSheet() {
    final titleController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Sub-task Title')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final st = Event()..title = titleController.text..dateTime = _selectedDate;
                  st.parent.value = widget.eventToEdit;
                  await context.read<EventRepository>().saveSubtask(st);
                  if (context.mounted) Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text('Add'),
            ),
            const SizedBox(height: 20),
          ],
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('YES')),
        ],
      )
    ) ?? false;
  }

  String _formatStatus(Status status) => status == Status.inProgress ? 'In Progress' : status.name[0].toUpperCase() + status.name.substring(1);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeInputController.dispose();
    _assigneeFocusNode.dispose();
    super.dispose();
  }
}
