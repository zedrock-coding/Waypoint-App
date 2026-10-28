import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:helm/models/hive_models.dart';
import 'package:helm/services/hive_database.dart';

void main() {
  late Directory tempDir;
  late Box<Category> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('helm_category_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    box = await Hive.openBox<Category>('categories');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await box.clear();
  });

  test('re-keys addAll-seeded integer rows to their category ids', () async {
    // Shape produced by the old `categoryBox.addAll([...])` seed.
    await box.add(Category(id: 'uuid-general', name: 'General'));
    await box.add(Category(id: 'uuid-work', name: 'Work'));
    await box.add(Category(id: 'uuid-personal', name: 'Personal'));

    expect(box.keys, everyElement(isA<int>()));

    await HiveDatabase.migrateCategoryKeys(box);

    expect(box.keys.toSet(), {'uuid-general', 'uuid-work', 'uuid-personal'});
    expect(box.length, 3);
    expect(box.get('uuid-general')!.name, 'General');
    expect(box.get('uuid-work')!.name, 'Work');
    expect(box.get('uuid-personal')!.name, 'Personal');
  });

  test('leaves already-correct string keys alone', () async {
    await box.put('uuid-a', Category(id: 'uuid-a', name: 'A'));

    await HiveDatabase.migrateCategoryKeys(box);

    expect(box.keys.toList(), ['uuid-a']);
    expect(box.length, 1);
  });

  test('gives a row without an id a fresh one and keeps it', () async {
    await box.add(Category(name: 'Legacy'));

    await HiveDatabase.migrateCategoryKeys(box);

    expect(box.length, 1);
    final category = box.values.single;
    expect(category.id, isNotNull);
    expect(category.id, isNotEmpty);
    expect(category.name, 'Legacy');
    expect(box.keys.single, category.id);
  });

  test(
    'drops a legacy duplicate instead of doubling the category list',
    () async {
      // Same category reachable under its id and under a stale key.
      await box.put('uuid-dup', Category(id: 'uuid-dup', name: 'Work'));
      await box.add(Category(id: 'uuid-dup', name: 'Work'));

      await HiveDatabase.migrateCategoryKeys(box);

      expect(box.length, 1);
      expect(box.keys.single, 'uuid-dup');
    },
  );

  test('is idempotent', () async {
    await box.add(Category(id: 'uuid-a', name: 'A'));
    await HiveDatabase.migrateCategoryKeys(box);
    await HiveDatabase.migrateCategoryKeys(box);

    expect(box.keys.toList(), ['uuid-a']);
    expect(box.length, 1);
  });
}
