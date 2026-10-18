// lib/providers/profile_refresh_provider.dart
import 'package:flutter/material.dart';

/// Сигнальная шина: любой экран может попросить ProfileScreen
/// перезагрузить статистику (для активации карты, pull-to-refresh и т.п.).
class ProfileRefreshProvider extends ChangeNotifier {
  int _tick = 0;
  int get tick => _tick;

  void requestRefresh() {
    _tick++;
    notifyListeners();
  }
}
