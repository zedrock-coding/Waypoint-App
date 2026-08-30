import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/hive_models.dart';
import '../models/sync_model.dart';

class HiveDatabase {
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(CommunityAdapter());
    Hive.registerAdapter(CommunityMemberAdapter());
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(SettingsAdapter());
    Hive.registerAdapter(SyncActionAdapter());
    Hive.registerAdapter(SyncActionTypeAdapter());

    // Open Boxes
    final categoryBox = await Hive.openBox<Category>('categories');
    await Hive.openBox<Community>('communities');
    await Hive.openBox<CommunityMember>('community_members');
    await Hive.openBox<Task>('tasks');
    await Hive.openBox<SyncAction>('sync_queue');
    final settingsBox = await Hive.openBox<Settings>('settings');

    // Seed default settings if empty
    if (settingsBox.isEmpty) {
      await settingsBox.put('app_settings', Settings());
    }

    // Seed default categories if empty
    if (categoryBox.isEmpty) {
      final uuid = Uuid();
      await categoryBox.addAll([
        Category(id: uuid.v4(), name: 'General'),
        Category(id: uuid.v4(), name: 'Work'),
        Category(id: uuid.v4(), name: 'Personal'),
      ]);
    }
  }

  /// Querying Roles in NoSQL
  /// To find who is an admin in a specific community, we iterate through the community_members box.
  static List<CommunityMember> getAdminsForCommunity(String communityId) {
    final memberBox = Hive.box<CommunityMember>('community_members');
    
    return memberBox.values.where((member) {
      return member.communityId == communityId && member.role == 'admin';
    }).toList();
  }
}
