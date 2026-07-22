import 'package:isar/isar.dart';
import '../models/event.dart';
import '../models/category.dart';

class EventRepository {
  final Isar isar;

  EventRepository(this.isar);

  Future<List<Event>> getAllEvents() async {
    return await isar.events.where().sortByDateTime().findAll();
  }

  Stream<void> watchEvents() {
    return isar.events.watchLazy();
  }

  Future<void> saveEvent(Event event, List<Category> selectedCategories) async {
    await isar.writeTxn(() async {
      await isar.events.put(event);
      event.categories.clear();
      event.categories.addAll(selectedCategories);
      await event.categories.save();
    });
  }

  Future<void> deleteEvent(Id id) async {
    await isar.writeTxn(() async {
      await isar.events.delete(id);
    });
  }

  Future<void> updateStatus(Event event, Status status) async {
    await isar.writeTxn(() async {
      event.status = status;
      await isar.events.put(event);
    });
  }

  Future<List<Event>> getEventsForToday() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return await isar.events.filter().dateTimeBetween(todayStart, todayEnd).findAll();
  }

  Future<List<Event>> getSubtasks(Id parentId) async {
    return await isar.events.filter().parent((q) => q.idEqualTo(parentId)).findAll();
  }

  Future<void> saveSubtask(Event subtask) async {
    await isar.writeTxn(() async {
      await isar.events.put(subtask);
      await subtask.parent.save();
    });
  }

  /// Optimized method to get the dashboard list in one go if possible
  Future<List<dynamic>> getDashboardList({
    bool sortByCategory = true,
    Id? selectedCategoryId,
  }) async {
    final List<dynamic> flattened = [];

    if (selectedCategoryId != null) {
      final events = await isar.events
          .filter()
          .categories((q) => q.idEqualTo(selectedCategoryId))
          .sortByDateTime()
          .findAll();
      
      final cat = await isar.categorys.get(selectedCategoryId);
      if (cat != null && events.isNotEmpty) {
        flattened.add(cat.name);
        flattened.addAll(events);
      }
    } else if (sortByCategory) {
      // 1. Fetch all events and their categories
      final events = await isar.events.where().sortByDateTime().findAll();
      
      // 2. Load links for all events in parallel if possible (Isar handles this well)
      for (var e in events) {
        await e.categories.load();
      }

      // 3. Group in memory
      final Map<String, List<Event>> grouped = {};
      final List<Event> uncategorized = [];

      for (var e in events) {
        if (e.categories.isEmpty) {
          uncategorized.add(e);
        } else {
          for (var cat in e.categories) {
            grouped.putIfAbsent(cat.name, () => []).add(e);
          }
        }
      }

      // 4. Flatten the map
      final sortedCategoryNames = grouped.keys.toList()..sort();
      for (var name in sortedCategoryNames) {
        flattened.add(name);
        flattened.addAll(grouped[name]!);
      }

      if (uncategorized.isNotEmpty) {
        flattened.add('Inbox');
        flattened.addAll(uncategorized);
      }
    } else {
      flattened.addAll(await isar.events.where().sortByDateTime().findAll());
    }

    return flattened;
  }
}
