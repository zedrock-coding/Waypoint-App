import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/hive_models.dart';
import 'theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  final Box<Settings> _settingsBox = Hive.box<Settings>('settings');
  Settings _settings = Settings();

  ThemeProvider() {
    _init();
  }

  Settings get settings => _settings;

  void _init() {
    final s = _settingsBox.get('app_settings');
    if (s != null) {
      _settings = s;
    }
    
    // Listen for changes
    _settingsBox.watch(key: 'app_settings').listen((event) {
      if (event.value != null) {
        _settings = event.value;
        notifyListeners();
      }
    });
  }

  ThemeMode get themeMode {
    return (_settings.themeMode ?? 1) == 1 ? ThemeMode.dark : ThemeMode.light;
  }

  double get textScaleFactor {
    return AppTheme.fontScales[(_settings.fontSizeIndex ?? 2).clamp(0, 4)];
  }

  Future<void> updateThemeMode(int mode) async {
    _settings.themeMode = mode;
    await _settings.save();
    notifyListeners();
  }
  
  Future<void> updateFontSize(int index) async {
    _settings.fontSizeIndex = index;
    await _settings.save();
    notifyListeners();
  }

  Future<void> toggleReminders(bool enabled) async {
    _settings.dailyBriefingEnabled = enabled;
    await _settings.save();
    notifyListeners();
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
    await _settings.save();
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}
