import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'models/settings.dart';
import 'theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  final Isar isar;
  Settings _settings = Settings();

  ThemeProvider(this.isar) {
    _init();
  }

  Settings get settings => _settings;

  Future<void> _init() async {
    final s = await isar.settings.get(0);
    if (s != null) {
      _settings = s;
      notifyListeners();
    }
    
    isar.settings.watchObject(0).listen((newSettings) {
      if (newSettings != null) {
        _settings = newSettings;
        notifyListeners();
      }
    });
  }

  ThemeMode get themeMode {
    return _settings.themeMode == 1 ? ThemeMode.dark : ThemeMode.light;
  }

  double get textScaleFactor {
    return AppTheme.fontScales[_settings.fontSizeIndex.clamp(0, 4)];
  }

  Future<void> updateThemeMode(int mode) async {
    _settings.themeMode = mode;
    notifyListeners();
    await isar.writeTxn(() => isar.settings.put(_settings));
  }
  
  Future<void> updateFontSize(int index) async {
    _settings.fontSizeIndex = index;
    notifyListeners();
    await isar.writeTxn(() => isar.settings.put(_settings));
  }

  Future<void> toggleReminders(bool enabled) async {
    _settings.dailyBriefingEnabled = enabled;
    notifyListeners();
    await isar.writeTxn(() => isar.settings.put(_settings));
  }

  Future<void> updateNotificationSetting(String key, bool value) async {
    switch (key) {
      case 'taskAssignments':
        _settings.taskAssignmentsEnabled = value;
        break;
      case 'dueDateReminders':
        _settings.dueDateRemindersEnabled = value;
        break;
      case 'communityMentions':
        _settings.communityMentionsEnabled = value;
        break;
      case 'dailyBriefing':
        _settings.dailyBriefingEnabled = value;
        break;
      case 'newsAndOffers':
        _settings.newsAndOffersEnabled = value;
        break;
    }
    notifyListeners();
    await isar.writeTxn(() => isar.settings.put(_settings));
  }

  void refresh() {
    notifyListeners();
  }
}
