import 'package:isar/isar.dart';
import 'category.dart';

part 'event.g.dart';

enum Status {
  toDo,
  inProgress,
  done,
}

enum Priority {
  low,
  medium,
  high,
}

@collection
class Event {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  late String description;

  late DateTime dateTime;

  @enumerated
  Status status = Status.toDo;

  @enumerated
  Priority priority = Priority.medium;

  List<String> assignees = [];

  final categories = IsarLinks<Category>();

  final parent = IsarLink<Event>();

  @Backlink(to: 'parent')
  final children = IsarLinks<Event>();
}
