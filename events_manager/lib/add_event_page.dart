import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'models/event.dart';
import 'models/category.dart';

class AddEventPage extends StatefulWidget {
  final Isar isar;
  const AddEventPage({super.key, required this.isar});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  List<Category> _availableCategories = [];
  final List<Category> _selectedCategories = [];
  bool _allowMultiple = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await widget.isar.categorys.where().findAll();
    setState(() {
      _availableCategories = categories;
    });
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final newEvent = Event()
        ..title = _titleController.text
        ..description = _descriptionController.text
        ..dateTime = _selectedDate;

      await widget.isar.writeTxn(() async {
        await widget.isar.events.put(newEvent);
        // Link categories
        newEvent.categories.addAll(_selectedCategories);
        await newEvent.categories.save();
      });

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Event'),
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
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text("Date: ${_selectedDate.toLocal()}".split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Allow Multiple Categories'),
                subtitle: const Text('Up to 5 categories'),
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
              _availableCategories.isEmpty 
                ? const Text('No categories created yet. Go to Categories menu to add some.')
                : Wrap(
                    spacing: 8.0,
                    children: _availableCategories.map((cat) {
                      final isSelected = _selectedCategories.any((element) => element.id == cat.id);
                      return FilterChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (!_allowMultiple) {
                                _selectedCategories.clear();
                                _selectedCategories.add(cat);
                              } else if (_selectedCategories.length < 5) {
                                _selectedCategories.add(cat);
                              }
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
                onPressed: _saveEvent,
                child: const Text('Save Event'),
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
    super.dispose();
  }
}
