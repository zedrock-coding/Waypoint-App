import 'package:hive/hive.dart';

part 'sync_model.g.dart';

@HiveType(typeId: 5)
enum SyncActionType {
  @HiveField(0)
  create,
  @HiveField(1)
  update,
  @HiveField(2)
  delete
}

@HiveType(typeId: 6)
class SyncAction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final SyncActionType action;

  @HiveField(2)
  final String table;

  @HiveField(3)
  final Map<dynamic, dynamic> payload;

  @HiveField(4)
  final DateTime timestamp;

  SyncAction({
    required this.id,
    required this.action,
    required this.table,
    required this.payload,
    required this.timestamp,
  });
}
