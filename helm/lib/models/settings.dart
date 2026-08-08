import 'package:isar/isar.dart';

part 'settings.g.dart';

@collection
class Settings {
  Id id = Isar.autoIncrement;

  int themeMode = 1; // 0: light, 1: dark, 2: system

  int fontSizeIndex = 2; // Default to medium

  bool remindersEnabled = true;

  // New detailed notification settings
  bool taskAssignmentsEnabled = true;
  bool dueDateRemindersEnabled = true;
  bool communityMentionsEnabled = true;
  bool dailyBriefingEnabled = true;
  bool newsAndOffersEnabled = false;

  String? customThemeJson;
}
