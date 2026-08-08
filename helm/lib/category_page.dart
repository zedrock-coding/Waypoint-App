import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/hive_models.dart' as hive_model;
import 'providers/task_provider.dart';
import 'app_shell.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _categoryController = TextEditingController();

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isNotEmpty) {
      await context.read<TaskProvider>().addCategory(name);
      _categoryController.clear();
    }
  }

  Future<void> _deleteCategory(String id) async {
    final taskProvider = context.read<TaskProvider>();
    final box = Hive.box<hive_model.Category>('categories');
    final cat = box.get(id);
    
    if (cat != null && (cat.name == 'General' || cat.name == 'Inbox')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This category cannot be deleted.')),
        );
      }
      return;
    }
    await taskProvider.deleteCategory(id);
  }

  @override
  Widget build(BuildContext context) {
    final categoryBox = Hive.box<hive_model.Category>('categories');

    return AppShell(
      title: 'Manage Categories',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'New Category Name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCategory,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: categoryBox.listenable(),
              builder: (context, Box<hive_model.Category> box, _) {
                final categories = box.values.toList();
                if (categories.isEmpty) {
                  return const Center(child: Text('No categories found.'));
                }
                
                return ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final String catId = category.id ?? '';
                    final String catName = category.name ?? 'Unnamed';

                    return ListTile(
                      title: Text(catName),
                      trailing: (catName == 'General' || catName == 'Inbox') ? null : IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(catId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }
}
