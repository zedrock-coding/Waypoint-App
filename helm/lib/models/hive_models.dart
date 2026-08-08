import 'package:hive/hive.dart';

part 'hive_models.g.dart';

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? name;

  Category({this.id, this.name});
}

@HiveType(typeId: 1)
class Community extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? name;

  @HiveField(2)
  String? creatorId;

  @HiveField(3)
  DateTime? createdAt;

  Community({
    this.id,
    this.name,
    this.creatorId,
    this.createdAt,
  });
}

@HiveType(typeId: 2)
class CommunityMember extends HiveObject {
  @HiveField(0)
  String? communityId;

  @HiveField(1)
  String? userId;

  @HiveField(2)
  String? role; // 'admin' or 'member'

  CommunityMember({
    this.communityId,
    this.userId,
    this.role,
  });
}

@HiveType(typeId: 3)
class Task extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  bool? isCompleted;

  @HiveField(4)
  String? userId; 

  @HiveField(5)
  String? communityId;

  @HiveField(6)
  String? categoryId;

  @HiveField(7)
  DateTime? createdAt;

  @HiveField(8)
  DateTime? dueAt;

  @HiveField(9)
  String? priority; 

  @HiveField(10)
  List<String>? assignees;

  @HiveField(11)
  String? status; 

  Task({
    this.id,
    this.title,
    this.description,
    this.isCompleted,
    this.userId,
    this.communityId,
    this.categoryId,
    this.createdAt,
    this.dueAt,
    this.priority = 'medium',
    this.assignees = const [],
    this.status = 'toDo',
  });
}

@HiveType(typeId: 4)
class Settings extends HiveObject {
  @HiveField(0)
  int? themeMode; // 0: light, 1: dark

  @HiveField(1)
  int? fontSizeIndex;

  @HiveField(2)
  bool? dailyBriefingEnabled;

  @HiveField(3)
  bool? taskAssignmentsEnabled;

  @HiveField(4)
  bool? dueDateRemindersEnabled;

  @HiveField(5)
  bool? communityMentionsEnabled;

  @HiveField(6)
  bool? newsAndOffersEnabled;

  Settings({
    this.themeMode = 1,
    this.fontSizeIndex = 2,
    this.dailyBriefingEnabled = true,
    this.taskAssignmentsEnabled = true,
    this.dueDateRemindersEnabled = true,
    this.communityMentionsEnabled = true,
    this.newsAndOffersEnabled = false,
  });
}
