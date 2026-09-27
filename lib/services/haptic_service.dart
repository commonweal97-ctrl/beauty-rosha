// lib/services/haptic_service.dart
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticService {
  static bool _enabled = true;
  static bool _loaded = false;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('vibration_enabled') ?? true;
    _loaded = true;
  }

  static Future<void> light() async {
    if (!_loaded) await init();
    if (_enabled) HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (!_loaded) await init();
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    if (!_loaded) await init();
    if (_enabled) HapticFeedback.heavyImpact();
  }

  static Future<void> selection() async {
    if (!_loaded) await init();
    if (_enabled) HapticFeedback.selectionClick();
  }

  /// Обновить настройку (вызвать при изменении тумблера)
  static void setEnabled(bool value) {
    _enabled = value;
  }
}