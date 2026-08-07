import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  bool isAdmin = false;

  final parent = IsarLink<Category>();

  @Backlink(to: 'parent')
  final subCategories = IsarLinks<Category>();
}
