import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import 'models/category.dart';
import 'app_shell.dart';
import 'repositories/category_repository.dart';

class CategoryPage extends StatefulWidget {
  final Isar isar;
  const CategoryPage({super.key, required this.isar});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _categoryController = TextEditingController();

  Future<void> _addCategory() async {
    if (_categoryController.text.isNotEmpty) {
      final categoryRepo = context.read<CategoryRepository>();
      final newCategory = Category()..name = _categoryController.text;
      await categoryRepo.saveCategory(newCategory);
      _categoryController.clear();
    }
  }

  Future<void> _deleteCategory(Id id) async {
    final categoryRepo = context.read<CategoryRepository>();
    final cat = await categoryRepo.getCategoryById(id);
    if (cat != null && cat.name == 'General') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The "General" category cannot be deleted.')),
        );
      }
      return;
    }
    await categoryRepo.deleteCategory(id);
  }

  @override
  Widget build(BuildContext context) {
    final categoryRepo = context.read<CategoryRepository>();

    return AppShell(
      title: 'Manage Categories',
      isar: widget.isar,
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
            child: StreamBuilder<List<Category>>(
              stream: categoryRepo.watchCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final categories = snapshot.data!;
                if (categories.isEmpty) return const Center(child: Text('No categories found.'));
                
                return ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      title: Text(category.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(category.id),
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
