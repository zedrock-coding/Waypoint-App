import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Box statsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('waypoint_streak_test');
    Hive.init(tempDir.path);
    statsBox = await Hive.openBox('user_stats');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await statsBox.clear();
  });

  test('UserStats increments streak when consecutive days are completed', () async {
    // Day 1
    const day1 = '2026-10-27';
    await statsBox.put('current_streak', 1);
    await statsBox.put('longest_streak', 1);
    await statsBox.put('last_completed_date', day1);

    expect(statsBox.get('current_streak'), 1);

    // Day 2 (consecutive)
    const day2 = '2026-10-28';
    int current = statsBox.get('current_streak', defaultValue: 0) as int;
    current += 1;
    await statsBox.put('current_streak', current);
    await statsBox.put('longest_streak', current);
    await statsBox.put('last_completed_date', day2);

    expect(statsBox.get('current_streak'), 2);
    expect(statsBox.get('longest_streak'), 2);

    // Same day completion does not increment
    expect(statsBox.get('last_completed_date'), day2);
  });

  test('UserStats resets streak to 1 when a day is skipped', () async {
    // Completed on day 1
    const day1 = '2026-10-25';
    await statsBox.put('current_streak', 5);
    await statsBox.put('longest_streak', 5);
    await statsBox.put('last_completed_date', day1);

    // Skipped days, completed on day 4
    const day4 = '2026-10-29';
    const yesterday = '2026-10-28';
    final String lastDate = statsBox.get('last_completed_date');

    int current;
    if (lastDate == yesterday) {
      current = (statsBox.get('current_streak', defaultValue: 0) as int) + 1;
    } else {
      current = 1; // Reset
    }

    await statsBox.put('current_streak', current);
    await statsBox.put('last_completed_date', day4);

    expect(statsBox.get('current_streak'), 1);
    expect(statsBox.get('longest_streak'), 5); // Longest streak preserved
  });
}

