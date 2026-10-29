import 'package:flutter/foundation.dart' show debugPrint;
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

    // Re-key categories seeded by older builds before deciding whether to seed.
    await migrateCategoryKeys(categoryBox);

    // Seed default categories if empty.
    //
    // `addAll` stored these under auto-increment integer keys while every
    // lookup (chips, filters, task.categoryIds) uses the category's UUID — so
    // the seeded categories were invisible to the filter UI and could not be
    // deleted. Key by the model id instead.
    if (categoryBox.isEmpty) {
      final uuid = Uuid();
      for (final name in const ['General', 'Work', 'Personal']) {
        final category = Category(id: uuid.v4(), name: name);
        await categoryBox.put(category.id!, category);
      }
    }
  }

  /// One-time migration for installs that already have `addAll`-seeded rows.
  ///
  /// The category *objects* already carry UUIDs, and tasks reference those UUIDs
  /// in `categoryIds`, so moving the box entry to its own id keeps every
  /// existing reference intact. Nothing is duplicated: an already-correct key is
  /// left alone, and a legacy key whose id is already present is simply dropped.
  ///
  /// Public so the migration can be exercised directly in tests.
  static Future<void> migrateCategoryKeys(Box<Category> categoryBox) async {
    final uuid = Uuid();

    // Pass 1: make sure every row has an id. A row without one cannot be
    // re-keyed and cannot be referenced, so give it one and keep it at its key.
    for (final entry in categoryBox.toMap().entries.toList()) {
      final category = entry.value;
      if (category.id == null || category.id!.isEmpty) {
        category.id = uuid.v4();
        await categoryBox.put(entry.key, category);
      }
    }

    // Pass 2: move every row to its id key.
    for (final entry in categoryBox.toMap().entries.toList()) {
      final key = entry.key;
      final category = entry.value;
      final id = category.id!;

      if (key is String && key == id) continue;

      if (!categoryBox.containsKey(id)) {
        // Re-instantiate: a HiveObject bound to one key should not be stored
        // under a second key.
        await categoryBox.put(
          id,
          Category(id: id, name: category.name, userId: category.userId),
        );
      }
      await categoryBox.delete(key);
      debugPrint('HiveDatabase: re-keyed category "$id" from $key');
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
