import 'package:isar/isar.dart';
import 'category.dart';

part 'event.g.dart';

@collection
class Event {
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  late String title;

  late String description;

  late DateTime dateTime;

  final categories = IsarLinks<Category>();
}
