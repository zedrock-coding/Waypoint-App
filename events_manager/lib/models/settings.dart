import 'package:isar/isar.dart';

part 'settings.g.dart';

@collection
class Settings {
  Id id = 0; // Singleton settings

  int fontSizeIndex = 2; // Default to 'Normal' (0: VS, 1: S, 2: N, 3: M, 4: L)

  int themeMode = 0; // 0: Light, 1: Dark, 2: Custom

  String? customThemeJson;

  // Essential Alerts
  bool taskAssignmentsEnabled = true;
  bool dueDateRemindersEnabled = true;
  bool communityMentionsEnabled = true;

  // General & Promotional
  bool dailyBriefingEnabled = true;
  bool newsAndOffersEnabled = false;

  // Legacy field - keeping for migration if needed, but will use dailyBriefingEnabled instead
  bool remindersEnabled = false;
}
