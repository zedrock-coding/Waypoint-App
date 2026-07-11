import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'models/category.dart';
import 'app_shell.dart';

class CategoryPage extends StatefulWidget {
  final Isar isar;
  const CategoryPage({super.key, required this.isar});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _categoryController = TextEditingController();
  late Stream<List<Category>> _categoryStream;

  @override
  void initState() {
    super.initState();
    _categoryStream = widget.isar.categorys
        .where()
        .watch(fireImmediately: true)
        .asBroadcastStream();
  }

  Future<void> _addCategory() async {
    if (_categoryController.text.isNotEmpty) {
      final newCategory = Category()..name = _categoryController.text;
      await widget.isar.writeTxn(() async {
        await widget.isar.categorys.put(newCategory);
      });
      _categoryController.clear();
    }
  }

  Future<void> _deleteCategory(Id id) async {
    await widget.isar.writeTxn(() async {
      await widget.isar.categorys.delete(id);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              stream: _categoryStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final categories = snapshot.data!;
                if (categories.isEmpty) {
                  return const Center(child: Text('No categories found.'));
                }
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
