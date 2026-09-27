import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  static final CrashlyticsService instance = CrashlyticsService._();
  
  CrashlyticsService._();

  // Логирование события (видно в Crashlytics Logs)
  static Future<void> log(String message) async {
    if (kDebugMode) {
      debugPrint('📝 ${DateTime.now().toIso8601String()} | $message');
      return;
    }
    
    await FirebaseCrashlytics.instance.log(message);
  }

  // Логирование ошибки (не фатальной)
  static Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) async {
    if (kDebugMode) {
      debugPrint('🔴 ${reason ?? "Error"}: $error');
      return;
    }
    
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
    );
  }

  // Установка ID пользователя (видно в Crashlytics)
  static Future<void> setUserIdentifier(String userId) async {
    if (kDebugMode) return;
    
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  // Добавление кастомного ключа (для фильтрации)
  static Future<void> setCustomKey(String key, String value) async {
    if (kDebugMode) return;
    
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
}