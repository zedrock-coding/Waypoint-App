import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/unified_task.dart';
import 'providers/task_provider.dart';
import 'services/supabase_service.dart';
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
  final TextEditingController _assigneeInputController = TextEditingController();
  final FocusNode _assigneeFocusNode = FocusNode();
  late DateTime _selectedDate;
  
  late Priority _selectedPriority;
  late Status _selectedStatus;
  
  List<hive_model.Category> _availableHiveCategories = [];
  final List<String> _selectedHiveCategoryIds = [];
  final List<String> _assignees = [];
  bool _hasUnsavedChanges = false;
  
  String? _selectedDestination; 
  List<Map<String, dynamic>> _userCommunities = [];
  bool _isUserLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _isUserLoggedIn = Supabase.instance.client.auth.currentUser != null;
    
    if (widget.initialCommunityId != null) {
      _selectedDestination = widget.initialCommunityId;
    } else {
      _selectedDestination = _isUserLoggedIn ? null : 'local';
    }
    
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descriptionController = TextEditingController(text: widget.taskToEdit?.description ?? '');
    if (widget.taskToEdit != null) {
      _assignees.addAll(widget.taskToEdit!.assignees);
    }
    _selectedDate = widget.taskToEdit?.dateTime ?? DateTime.now();
    _selectedPriority = widget.taskToEdit?.priority ?? Priority.medium;
    _selectedStatus = widget.taskToEdit?.status ?? Status.toDo;

    if (widget.taskToEdit?.categoryId != null) {
      _selectedHiveCategoryIds.add(widget.taskToEdit!.categoryId!);
    }
    
    _loadHiveCategories();
    _loadSupabaseCommunities();

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

  void _markChanges() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
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
      _assigneeFocusNode.requestFocus();
    } else {
      _assigneeInputController.clear();
      _assigneeFocusNode.requestFocus();
    }
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      try {
        final taskProvider = context.read<TaskProvider>();
        
        if (widget.taskToEdit != null) {
          await taskProvider.updateTask(
            id: widget.taskToEdit!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            categoryId: _selectedHiveCategoryIds.firstOrNull,
            priority: _selectedPriority,
            status: _selectedStatus,
          );
        } else {
          final String? communityId = (_selectedDestination != null && _selectedDestination != 'local') 
              ? _selectedDestination 
              : null;
              
          final bool isLocalOnly = _selectedDestination == 'local';

          await taskProvider.addTask(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            communityId: communityId,
            categoryId: _selectedHiveCategoryIds.firstOrNull,
            priority: _selectedPriority,
            status: _selectedStatus,
            isLocalOnly: isLocalOnly,
          );
        }

        _hasUnsavedChanges = false;
        if (mounted) Navigator.pop(context);
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
    final isEditing = widget.taskToEdit != null;

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
          _buildDestinationSelector(),
          const SizedBox(height: 16),
          if (_selectedDestination == null || _selectedDestination == 'local') _buildCategorySelection(),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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

  String _formatStatus(Status s) {
    if (s == Status.inProgress) return 'In Progress';
    return s.name;
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
      title: Text("Due Date: ${DateFormat.yMMMd().format(_selectedDate)}"),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2101));
        if (picked != null) setState(() { _selectedDate = picked; _hasUnsavedChanges = true; });
      },
    );
  }

  Widget _buildDestinationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Destination:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _selectedDestination,
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
                    Icon(Icons.cloud_done_outlined, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Personal (Cloud Sync)'),
                  ],
                )
              ),
            const DropdownMenuItem(
              value: 'local', 
              child: Row(
                children: [
                  Icon(Icons.smartphone_rounded, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Device Only (Offline)'),
                ],
              )
            ),
            ..._userCommunities.map((comm) => DropdownMenuItem(
              value: comm['id'].toString(),
              child: Row(
                children: [
                  const Icon(Icons.hub_rounded, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text('Community: ${comm['name']}'),
                ],
              ),
            )),
          ],
          onChanged: (val) {
            setState(() {
              _selectedDestination = val;
              _hasUnsavedChanges = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Apply Category (Tag):', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _availableHiveCategories.map((cat) {
            final String catId = cat.id ?? '';
            final isSelected = _selectedHiveCategoryIds.contains(catId);
            return FilterChip(
              label: Text(cat.name ?? 'Unnamed'),
              selected: isSelected,
              onSelected: (selected) => setState(() {
                _hasUnsavedChanges = true;
                if (selected) {
                  _selectedHiveCategoryIds.clear(); 
                  _selectedHiveCategoryIds.add(catId);
                } else {
                  _selectedHiveCategoryIds.remove(catId);
                }
              }),
            );
          }).toList(),
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assigneeInputController.dispose();
    _assigneeFocusNode.dispose();
    super.dispose();
  }
}
