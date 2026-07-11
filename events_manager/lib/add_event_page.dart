import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'models/event.dart';
import 'models/category.dart';

class AddEventPage extends StatefulWidget {
  final Isar isar;
  final Event? eventToEdit;

  const AddEventPage({super.key, required this.isar, this.eventToEdit});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final TextEditingController _assigneeInputController = TextEditingController();
  late DateTime _selectedDate;
  
  late Status _selectedStatus;
  late Priority _selectedPriority;
  
  List<Category> _availableCategories = [];
  final List<Category> _selectedCategories = [];
  final List<String> _assignees = [];
  bool _allowMultiple = true;

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
      });
    } else {
      _assigneeInputController.clear();
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

        await widget.isar.writeTxn(() async {
          await widget.isar.events.put(event);
          event.categories.clear();
          event.categories.addAll(_selectedCategories);
          await event.categories.save();
        });

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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'Add New Task'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
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
                        child: Text(s.name.toUpperCase()),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedStatus = val!),
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
                      onChanged: (val) => setState(() => _selectedPriority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Dynamic Chip Input Area
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _assigneeInputController,
                    decoration: const InputDecoration(
                      labelText: 'Add Assignee', 
                      hintText: 'Type name and press Enter or comma',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) => _addAssignee(value),
                    onChanged: (value) {
                      if (value.endsWith(',')) {
                        _addAssignee(value);
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
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const Divider(height: 32),
              SwitchListTile(
                title: const Text('Allow Multiple Categories'),
                value: _allowMultiple,
                onChanged: (val) {
                  setState(() {
                    _allowMultiple = val;
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
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _saveEvent,
                child: Text(isEditing ? 'Update Task' : 'Save Task'),
              ),
            ],
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
    super.dispose();
  }
}
