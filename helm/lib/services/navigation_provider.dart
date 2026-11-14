import 'package:flutter/material.dart';

enum WaypointNavView { today, inbox, recurring, schedule, settings, communities, account }

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
    _selectedCommunityId = null;
    _selectedCommunityName = null;
    _selectedIndex = view == WaypointNavView.communities ? 1 : 0;

    if (view == WaypointNavView.today) {
      _currentRoute = '/';
    } else if (view == WaypointNavView.inbox) {
      _currentRoute = '/inbox';
    } else if (view == WaypointNavView.recurring) {
      _currentRoute = '/recurring';
    } else if (view == WaypointNavView.schedule) {
      _currentRoute = '/calendar';
    } else if (view == WaypointNavView.settings) {
      _currentRoute = '/settings';
    } else if (view == WaypointNavView.communities) {
      _currentRoute = '/communities';
    } else if (view == WaypointNavView.account) {
      _currentRoute = '/account';
    }
    notifyListeners();
  }

  void selectCommunity(String? id, {String? name}) {
    _selectedCommunityId = id;
    _selectedCommunityName = name;
    _currentRoute = '/';
    _selectedIndex = id != null ? 1 : 0;
    _currentView = WaypointNavView.today;
    notifyListeners();
  }

  void exitCommunity() {
    _selectedCommunityId = null;
    _selectedCommunityName = null;
    _selectedIndex = 0;
    _currentView = WaypointNavView.today;
    _currentRoute = '/';
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
    } else if (route == '/account') {
      _currentView = WaypointNavView.account;
    }
    notifyListeners();
  }
}
