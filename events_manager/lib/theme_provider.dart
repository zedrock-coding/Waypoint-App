import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'models/settings.dart';

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
    // Watch for external changes (like from other pages)
    isar.settings.watchObject(0).listen((newSettings) {
      if (newSettings != null) {
        _settings = newSettings;
        notifyListeners();
      }
    });
  }

  ThemeMode get themeMode {
    // 0: Light, 1: Dark
    if (_settings.themeMode == 1) return ThemeMode.dark;
    return ThemeMode.light; 
  }

  Future<void> updateThemeMode(int mode) async {
    _settings.themeMode = mode;
    notifyListeners();
    await isar.writeTxn(() async {
      await isar.settings.put(_settings);
    });
  }
  
  // Font size management integrated here for stability
  Future<void> updateFontSize(int index) async {
    _settings.fontSizeIndex = index;
    notifyListeners();
    await isar.writeTxn(() async {
      await isar.settings.put(_settings);
    });
  }

  // Public method to allow external components to trigger a UI refresh
  void refresh() {
    notifyListeners();
  }
}
