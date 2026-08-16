import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  String? _selectedCommunityId;
  String? _selectedCommunityName;
  String _currentRoute = '/';
  int _selectedIndex = 0; // 0: Personal, 1: Communities

  String? get selectedCommunityId => _selectedCommunityId;
  String? get selectedCommunityName => _selectedCommunityName;
  String get currentRoute => _currentRoute;
  int get selectedIndex => _selectedIndex;

  void selectCommunity(String? id, {String? name}) {
    _selectedCommunityId = id;
    _selectedCommunityName = name;
    _currentRoute = '/'; 
    _selectedIndex = 1; // Switch to communities tab if a community is selected
    notifyListeners();
  }

  void setTab(int index) {
    _selectedIndex = index;
    _currentRoute = '/';
    if (index == 0) {
      _selectedCommunityId = null;
    }
    notifyListeners();
  }

  void setRoute(String route) {
    _currentRoute = route;
    if (route != '/') {
      _selectedCommunityId = null;
    } else {
      // If we are explicitly navigating to '/', we assume Personal Dashboard
      _selectedIndex = 0;
      _selectedCommunityId = null;
    }
    notifyListeners();
  }
}
