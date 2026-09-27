// lib/core/app_logger.dart
//
// Единая точка логирования.
// В dev — print, в prod — только ошибки в Crashlytics.
//
// Правила:
//   • info    — только в dev (в prod полностью вырезается).
//   • warning — в dev print, в prod — Crashlytics (с rate-limit).
//   • error   — в dev print, в prod — Crashlytics.
//   • fatal   — всегда Crashlytics.

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AppLogger {
  AppLogger._();

  static bool _crashlyticsAvailable = true;

  /// Rate-limit: не чаще 1 warning в N секунд.
  /// Спасает от случайных циклов, которые зальют Crashlytics.
  static const _warningThrottleSeconds = 10;
  static final Map<String, DateTime> _lastWarningAt = {};

  static bool _shouldSendWarning(String key) {
    final now = DateTime.now();
    final last = _lastWarningAt[key];
    if (last != null &&
        now.difference(last).inSeconds < _warningThrottleSeconds) {
      return false;
    }
    _lastWarningAt[key] = now;

    // Защита от утечки памяти при большом количестве ключей.
    if (_lastWarningAt.length > 100) {
      _lastWarningAt.clear();
    }
    return true;
  }

  static void _safeCrashlytics(void Function() fn) {
    if (!_crashlyticsAvailable) return;
    try {
      fn();
    } catch (_) {
      _crashlyticsAvailable = false;
    }
  }

  /// Обычное информационное сообщение — только в dev.
  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [$tag] $message');
    }
  }

  /// Предупреждение.
  /// В dev — print. В prod — Crashlytics (с rate-limit).
  static void warning(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('⚠️ [$tag] $message${error != null ? ' | $error' : ''}');
    }

    if (kReleaseMode && _shouldSendWarning(tag)) {
      _safeCrashlytics(() {
        FirebaseCrashlytics.instance.log(
          '⚠️ [$tag] $message${error != null ? ' | $error' : ''}',
        );
      });
    }
  }

  /// Ошибка (не фатальная).
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      debugPrint('🔴 [$tag] $message${error != null ? ' | $error' : ''}');
    }

    if (error != null) {
      _safeCrashlytics(() {
        FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace ?? StackTrace.current,
          reason: '[$tag] $message',
          fatal: false,
        );
      });
    }
  }

  /// Фатальная ошибка.
  static void fatal(
    String tag,
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      debugPrint('💥 [$tag] $message | $error');
    }

    _safeCrashlytics(() {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: '[$tag] $message',
        fatal: true,
      );
    });
  }
}