import 'package:isar/isar.dart';
import '../models/category.dart';

class CategoryRepository {
  final Isar isar;

  CategoryRepository(this.isar);

  Future<List<Category>> getAllCategories() async {
    return await isar.categorys.where().sortByName().findAll();
  }

  Stream<List<Category>> watchCategories() {
    return isar.categorys.where().watch(fireImmediately: true);
  }

  Future<Category?> getCategoryById(Id id) async {
    return await isar.categorys.get(id);
  }

  Future<Category?> getCategoryByName(String name) async {
    return await isar.categorys.filter().nameEqualTo(name).findFirst();
  }

  Future<void> saveCategory(Category category) async {
    await isar.writeTxn(() async {
      await isar.categorys.put(category);
    });
  }

  Future<void> deleteCategory(Id id) async {
    await isar.writeTxn(() async {
      await isar.categorys.delete(id);
    });
  }

  Future<void> ensureGeneralCategoryExists() async {
    final existingGeneral = await isar.categorys.filter().nameEqualTo('General').findFirst();
    if (existingGeneral == null) {
      await saveCategory(Category()..name = 'General');
    }
  }

  Stream<List<Category>> watchRootCategories() {
    return isar.categorys.filter().parentIsNull().watch(fireImmediately: true);
  }
}
