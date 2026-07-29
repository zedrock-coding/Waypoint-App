import 'package:hive/hive.dart';

part 'hive_models.g.dart';

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  Category({required this.id, required this.name});
}

@HiveType(typeId: 1)
class Community extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String creatorId;

  @HiveField(3)
  DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.createdAt,
  });
}

@HiveType(typeId: 2)
class CommunityMember extends HiveObject {
  @HiveField(0)
  String communityId;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String role; // 'admin' or 'member'

  CommunityMember({
    required this.communityId,
    required this.userId,
    required this.role,
  });
}
