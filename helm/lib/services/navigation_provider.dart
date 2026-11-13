import 'package:flutter/material.dart';

enum WaypointNavView { today, inbox, recurring, schedule, settings, communities }

class NavigationProvider with ChangeNotifier {
  String? _selectedCommunityId;
  String? _selectedCommunityName;
  String _currentRoute = '/';
  int _selectedIndex = 0; // 0: Personal, 1: Communities
  WaypointNavView _currentView = WaypointNavView.today;

  String? get selectedCommunityId => _selectedCommunityId;
  String? get selectedCommunityName => _selectedCommunityName;
  String get currentRoute => _currentRoute;
  int get selectedIndex => _selectedIndex;
  WaypointNavView get currentView => _currentView;

  void setView(WaypointNavView view) {
    _currentView = view;
    if (view == WaypointNavView.today) {
      _currentRoute = '/';
      _selectedIndex = 0;
      _selectedCommunityId = null;
    } else if (view == WaypointNavView.schedule) {
      _currentRoute = '/calendar';
    } else if (view == WaypointNavView.settings) {
      _currentRoute = '/settings';
    } else if (view == WaypointNavView.communities) {
      _currentRoute = '/communities';
      _selectedIndex = 1;
    }
    notifyListeners();
  }

  void selectCommunity(String? id, {String? name}) {
    _selectedCommunityId = id;
    _selectedCommunityName = name;
    _currentRoute = '/';
    _selectedIndex = 1;
    _currentView = WaypointNavView.today; // Show community tasks on today worklist
    notifyListeners();
  }

  void setTab(int index) {
    _selectedIndex = index;
    _currentRoute = '/';
    _selectedCommunityId = null;
    _currentView = index == 0 ? WaypointNavView.today : WaypointNavView.communities;
    notifyListeners();
  }

  void setRoute(String route) {
    _currentRoute = route;
    if (route == '/') {
      _selectedIndex = 0;
      _selectedCommunityId = null;
      _currentView = WaypointNavView.today;
    } else if (route == '/calendar') {
      _currentView = WaypointNavView.schedule;
    } else if (route == '/settings') {
      _currentView = WaypointNavView.settings;
    } else if (route == '/categories' || route == '/communities') {
      _currentView = WaypointNavView.communities;
    }
    notifyListeners();
  }
}
