// lib/services/push_permission_service.dart

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Сервис управления разрешениями на push-уведомления.
///
/// Ответственность:
/// - Проверка системного статуса разрешений
/// - Синхронизация флагов с реальным состоянием
/// - Запрос разрешений с учётом платформы
/// - Открытие системных настроек при необходимости
class PushPermissionService {
  static const String _keyLastShown = 'push_dialog_last_shown';
  static const String _keyLastDismissed = 'push_dialog_last_dismissed';
  static const String _keyPermissionGranted = 'push_permission_granted';

  /// Проверяет, нужно ли показывать попап с запросом разрешения.
  static Future<bool> shouldShowDialog() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Не показываем на первом запуске
    final countrySelected = prefs.getBool('country_selected') ?? false;
    if (!countrySelected) return false;

    // 2. Проверяем авторизацию
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return false;

    // 3. Синхронизируем флаг с реальным статусом
    final authorizationStatus = await getAuthorizationStatus();

    if (authorizationStatus == PushPermissionStatus.authorized ||
        authorizationStatus == PushPermissionStatus.provisional) {
      await prefs.setBool(_keyPermissionGranted, true);
      return false;
    } else {
      await prefs.setBool(_keyPermissionGranted, false);
    }

    // 4. Проверяем историю показов
    final lastShown = prefs.getString(_keyLastShown);
    final lastDismissed = prefs.getString(_keyLastDismissed);

    if (lastShown == null) return true;

    if (lastDismissed != null) {
      final dismissedDate = DateTime.tryParse(lastDismissed);
      if (dismissedDate != null) {
        final hoursSince = DateTime.now().difference(dismissedDate).inHours;
        if (hoursSince < 24) return false;
      }
    }

    final shownDate = DateTime.tryParse(lastShown);
    if (shownDate != null) {
      final hoursSince = DateTime.now().difference(shownDate).inHours;
      return hoursSince >= 24;
    }

    return false;
  }

  /// Сохраняет время последнего показа попапа.
  static Future<void> saveLastShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastShown, DateTime.now().toIso8601String());
  }

  /// Сохраняет время последнего закрытия попапа.
  static Future<void> saveLastDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastDismissed, DateTime.now().toIso8601String());
  }

  /// Сохраняет флаг, что пользователь согласился на пуши.
  static Future<void> setPermissionGranted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPermissionGranted, value);
  }

  /// Возвращает текущий статус разрешений.
  static Future<PushPermissionStatus> getAuthorizationStatus() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      return _mapAuthorizationStatus(settings.authorizationStatus);
    } catch (e) {
      return PushPermissionStatus.unknown;
    }
  }

  /// Запрашивает системное разрешение на пуши.
  /// Возвращает `true`, если разрешение получено.
  static Future<bool> requestPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final currentStatus = await messaging.getNotificationSettings();

      if (currentStatus.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      if (currentStatus.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        final granted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;

        if (granted) {
          await setPermissionGranted(true);
        }

        return granted;
      }

      if (currentStatus.authorizationStatus == AuthorizationStatus.authorized ||
          currentStatus.authorizationStatus ==
              AuthorizationStatus.provisional) {
        await setPermissionGranted(true);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Открывает системные настройки приложения.
  static Future<bool> openAppSettings() async {
    try {
      if (Platform.isIOS) {
        final uri = Uri.parse('app-settings:');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return true;
        }
      } else if (Platform.isAndroid) {
        final uri = Uri.parse('android.settings.APPLICATION_DETAILS_SETTINGS');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Показывает диалог с предложением открыть настройки.
  static Future<bool> showSettingsDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Уведомления отключены',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Чтобы получать уведомления о заказах, акциях и новостях, '
          'разрешите их в настройках устройства.',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF666666),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Позже',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDD1847),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Открыть настройки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final opened = await openAppSettings();

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Platform.isIOS
                  ? 'Откройте Настройки → Уведомления → Б-Роща'
                  : 'Откройте Настройки → Приложения → Б-Роща → Уведомления',
              style: const TextStyle(fontSize: 15),
            ),
            backgroundColor: const Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    return result ?? false;
  }

  /// Маппинг AuthorizationStatus → PushPermissionStatus.
  ///
  /// Без `default:` — если Firebase добавит новое значение в enum,
  /// компилятор сам сообщит, что switch неисчерпывающий.
  static PushPermissionStatus _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return PushPermissionStatus.authorized;
      case AuthorizationStatus.denied:
        return PushPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermissionStatus.notDetermined;
      case AuthorizationStatus.provisional:
        return PushPermissionStatus.provisional;
    }
  }
}

/// Статус разрешений на push-уведомления.
enum PushPermissionStatus {
  authorized,
  denied,
  notDetermined,
  provisional,
  unknown,
}